import Foundation
import CoreFoundation
import NaturalLanguage

/// T-211 순수 로직 액션 — 언어 감지·측정 변환·날짜 조정·딕셔너리·목록·출력 저장
///
/// `TextActions`/`DataActions`와 같은 원칙을 따른다.
/// - **실패를 빈 문자열로 뭉개지 않는다.** "빈 결과"와 "형식 오류"를 구분한다
/// - 가능한 한 순수 함수로 두어 권한·UI 없이 테스트한다
/// - 날짜·언어처럼 로케일이 개입하는 계산은 `en_US_POSIX`/명시 로케일로 고정한다
enum NextActions {

    enum Outcome: Equatable {
        case success(String)
        case failure(FailureReason)

        var text: String {
            switch self {
            case .success(let value): return value
            case .failure: return ""
            }
        }

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    enum FailureReason: Equatable {
        case emptyInput
        case noDominantLanguage
        case invalidMeasurement(String)
        case dimensionMismatch
        case invalidDate(String)
        case invalidDictionary
        case missingKey(String)
        case emptyPath
        case saveFailed(String)

        var messageKey: String {
            switch self {
            case .emptyInput: return "error.user.text_empty"
            case .noDominantLanguage: return "error.user.next_language_missing"
            case .invalidMeasurement: return "error.user.next_measurement_invalid"
            case .dimensionMismatch: return "error.user.next_measurement_dimension"
            case .invalidDate: return "error.user.next_date_invalid"
            case .invalidDictionary: return "error.user.next_dictionary_invalid"
            case .missingKey: return "error.user.next_dictionary_key_missing"
            case .emptyPath: return "error.user.next_path_empty"
            case .saveFailed: return "error.user.next_save_failed"
            }
        }
    }

    // MARK: - 언어 감지

    /// `NLLanguageRecognizer`로 주 언어를 감지한다.
    ///
    /// 빈 입력은 실패다 — "감지 결과 없음"과 "입력이 없음"을 구분한다.
    /// 결과는 `ko (한국어)`처럼 코드와 지역화 이름을 함께 준다. 코드만 주면
    /// 사용자가 다음 단계에서 비교하기 어렵고, 이름만 주면 분기가 불안정하다.
    static func detectLanguage(_ input: String) -> Outcome {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyInput) }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        guard let language = recognizer.dominantLanguage else {
            return .failure(.noDominantLanguage)
        }
        let code = language.rawValue
        let name = Locale.current.localizedString(forLanguageCode: code) ?? code
        return .success("\(code) (\(name))")
    }

    // MARK: - 측정 변환

    enum MeasurementDimension: String, Codable, CaseIterable, Hashable {
        case length
        case mass
        case temperature
        case volume
    }

    enum MeasurementUnit: String, Codable, CaseIterable, Hashable {
        // 길이
        case meters = "m"
        case kilometers = "km"
        case centimeters = "cm"
        case millimeters = "mm"
        case miles = "mi"
        case feet = "ft"
        case inches = "in"
        case yards = "yd"
        // 질량
        case kilograms = "kg"
        case grams = "g"
        case pounds = "lb"
        case ounces = "oz"
        // 온도
        case celsius = "°C"
        case fahrenheit = "°F"
        case kelvin = "K"
        // 부피
        case liters = "L"
        case milliliters = "mL"
        case gallons = "gal"

        var dimension: MeasurementDimension {
            switch self {
            case .meters, .kilometers, .centimeters, .millimeters,
                 .miles, .feet, .inches, .yards:
                return .length
            case .kilograms, .grams, .pounds, .ounces:
                return .mass
            case .celsius, .fahrenheit, .kelvin:
                return .temperature
            case .liters, .milliliters, .gallons:
                return .volume
            }
        }

        /// 단위 기호 — 로케일과 무관하게 같은 값을 보여준다
        var symbol: String { rawValue }

        /// 입력에서 읽은 단위 문자열을 해석한다 (대소문자·복수형 허용)
        static func parse(_ token: String) -> MeasurementUnit? {
            let normalized = token
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "°", with: "")
            switch normalized {
            case "m", "meter", "meters": return .meters
            case "km", "kilometer", "kilometers": return .kilometers
            case "cm", "centimeter", "centimeters": return .centimeters
            case "mm", "millimeter", "millimeters": return .millimeters
            case "mi", "mile", "miles": return .miles
            case "ft", "foot", "feet": return .feet
            case "in", "inch", "inches": return .inches
            case "yd", "yard", "yards": return .yards
            case "kg", "kilogram", "kilograms": return .kilograms
            case "g", "gram", "grams": return .grams
            case "lb", "lbs", "pound", "pounds": return .pounds
            case "oz", "ounce", "ounces": return .ounces
            case "c", "celsius": return .celsius
            case "f", "fahrenheit": return .fahrenheit
            case "k", "kelvin": return .kelvin
            case "l", "liter", "liters", "litre", "litres": return .liters
            case "ml", "milliliter", "milliliters": return .milliliters
            case "gal", "gallon", "gallons": return .gallons
            default: return nil
            }
        }
    }

    /// 측정값을 다른 단위로 변환한다.
    ///
    /// 입력은 `12.5 m`처럼 값과 단위를 함께 쓰거나, `measurementFromUnit`이
    /// 지정된 경우 숫자만 쓴다. 차원(길이/질량/온도/부피)이 다르면 실패한다 —
    /// 0으로 뭉개면 "변환했는데 왜 이상하지"가 남는다.
    static func measurement(
        _ input: String,
        from: MeasurementUnit?,
        to: MeasurementUnit
    ) -> Outcome {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyInput) }

        let parsed: (value: Double, unit: MeasurementUnit)
        if let from {
            guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")),
                  value.isFinite else {
                return .failure(.invalidMeasurement(trimmed))
            }
            parsed = (value, from)
        } else {
            let pattern = #"^\s*([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)\s*([^\s0-9].*?)\s*$"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(
                    in: trimmed,
                    range: NSRange(location: 0, length: trimmed.utf16.count)
                  ),
                  match.numberOfRanges == 3,
                  let valueRange = Range(match.range(at: 1), in: trimmed),
                  let unitRange = Range(match.range(at: 2), in: trimmed),
                  let value = Double(String(trimmed[valueRange])),
                  let unit = MeasurementUnit.parse(String(trimmed[unitRange])) else {
                return .failure(.invalidMeasurement(trimmed))
            }
            parsed = (value, unit)
        }

        guard parsed.unit.dimension == to.dimension else {
            return .failure(.dimensionMismatch)
        }

        let converted = convert(parsed.value, from: parsed.unit, to: to)
        return .success("\(formatNumber(converted)) \(to.symbol)")
    }

    private static func convert(
        _ value: Double,
        from: MeasurementUnit,
        to: MeasurementUnit
    ) -> Double {
        if from == to { return value }
        switch from.dimension {
        case .length:
            return Measurement(value: value, unit: lengthUnit(from))
                .converted(to: lengthUnit(to)).value
        case .mass:
            return Measurement(value: value, unit: massUnit(from))
                .converted(to: massUnit(to)).value
        case .temperature:
            return Measurement(value: value, unit: temperatureUnit(from))
                .converted(to: temperatureUnit(to)).value
        case .volume:
            return Measurement(value: value, unit: volumeUnit(from))
                .converted(to: volumeUnit(to)).value
        }
    }

    private static func lengthUnit(_ unit: MeasurementUnit) -> UnitLength {
        switch unit {
        case .meters: return .meters
        case .kilometers: return .kilometers
        case .centimeters: return .centimeters
        case .millimeters: return .millimeters
        case .miles: return .miles
        case .feet: return .feet
        case .inches: return .inches
        case .yards: return .yards
        default: return .meters
        }
    }

    private static func massUnit(_ unit: MeasurementUnit) -> UnitMass {
        switch unit {
        case .kilograms: return .kilograms
        case .grams: return .grams
        case .pounds: return .pounds
        case .ounces: return .ounces
        default: return .kilograms
        }
    }

    private static func temperatureUnit(_ unit: MeasurementUnit) -> UnitTemperature {
        switch unit {
        case .celsius: return .celsius
        case .fahrenheit: return .fahrenheit
        default: return .kelvin
        }
    }

    private static func volumeUnit(_ unit: MeasurementUnit) -> UnitVolume {
        switch unit {
        case .liters: return .liters
        case .milliliters: return .milliliters
        case .gallons: return .gallons
        default: return .liters
        }
    }

    /// 소수점 아래 불필요한 0을 지운다 (12.500 → 12.5, 12.0 → 12)
    static func formatNumber(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int64(value))
        }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 6
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    // MARK: - 날짜 조정

    enum DateUnit: String, Codable, CaseIterable, Hashable {
        case seconds
        case minutes
        case hours
        case days
        case weeks
        case months
        case years

        var displayName: String {
            switch self {
            case .seconds: return "unit.date.seconds".localized
            case .minutes: return "unit.date.minutes".localized
            case .hours: return "unit.date.hours".localized
            case .days: return "unit.date.days".localized
            case .weeks: return "unit.date.weeks".localized
            case .months: return "unit.date.months".localized
            case .years: return "unit.date.years".localized
            }
        }

        var calendarComponent: Calendar.Component {
            switch self {
            case .seconds: return .second
            case .minutes: return .minute
            case .hours: return .hour
            case .days: return .day
            case .weeks: return .weekOfYear
            case .months: return .month
            case .years: return .year
            }
        }
    }

    /// 날짜를 더하거나 뺀다. 입력이 비면 "지금"을 기준으로 한다.
    ///
    /// 출력은 `format`이 있으면 그 형식, 없으면 ISO 8601. 다음 단계가 다시
    /// 날짜로 해석할 수 있도록 로케일 의존 형식을 기본값으로 쓰지 않는다.
    static func adjustDate(
        _ input: String,
        amount: Double,
        unit: DateUnit,
        format: String? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Outcome {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let base: Date
        if trimmed.isEmpty {
            base = now
        } else if let parsed = parseDate(trimmed) {
            base = parsed
        } else {
            return .failure(.invalidDate(trimmed))
        }

        let value = Int(amount.rounded())
        guard let adjusted = calendar.date(
            byAdding: unit.calendarComponent,
            value: value,
            to: base
        ) else {
            return .failure(.invalidDate(trimmed))
        }
        return .success(formatDate(adjusted, format: format))
    }

    /// 날짜 문자열을 해석한다. ISO 8601 → 일반 날짜 형식 순서.
    static func parseDate(_ input: String) -> Date? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: trimmed) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: trimmed) { return date }

        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    /// 날짜를 문자열로 만든다 (adjustDate · typeDateTime 공용)
    static func formatDate(_ date: Date, format: String? = nil) -> String {
        let fmt = (format?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? "yyyy-MM-dd'T'HH:mm:ssXXXXX"

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = fmt
        return formatter.string(from: date)
    }

    // MARK: - 잠자기 방지

    enum PreventSleepMode: String, Codable, CaseIterable, Hashable {
        case on
        case off
        case toggle
        case status

        var displayName: String {
            switch self {
            case .on: return "mode.prevent_sleep.on".localized
            case .off: return "mode.prevent_sleep.off".localized
            case .toggle: return "mode.prevent_sleep.toggle".localized
            case .status: return "mode.prevent_sleep.status".localized
            }
        }
    }

    // MARK: - 딕셔너리
    /// JSON 또는 plist 딕셔너리에서 값을 읽는다.
    ///
    /// `key`는 점(.)으로 중첩을 탐색한다 (`user.name`). 키가 비면 전체를
    /// 정렬된 JSON으로 돌려준다 — 다음 단계가 그대로 저장·전달할 수 있다.
    static func dictionary(_ input: String, key: String?) -> Outcome {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyInput) }
        guard let data = trimmed.data(using: .utf8),
              let root = parseDictionary(data) else {
            return .failure(.invalidDictionary)
        }

        let path = (key ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            return .success(jsonString(root))
        }

        var current: Any = root
        for component in path.split(separator: ".").map(String.init) {
            guard let dict = current as? [String: Any],
                  let next = dict[component] else {
                return .failure(.missingKey(path))
            }
            current = next
        }
        return .success(stringify(current))
    }

    private static func parseDictionary(_ data: Data) -> [String: Any]? {
        if let object = try? JSONSerialization.jsonObject(with: data),
           let dict = object as? [String: Any] {
            return dict
        }
        if let object = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ), let dict = object as? [String: Any] {
            return dict
        }
        return nil
    }

    private static func stringify(_ value: Any) -> String {
        if let text = value as? String { return text }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return NextActions.formatNumber(number.doubleValue)
        }
        if value is NSNull { return "" }
        return jsonString(value)
    }

    private static func jsonString(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(
                withJSONObject: value,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let text = String(data: data, encoding: .utf8) else {
            return ""
        }
        return text
    }

    // MARK: - 목록

    /// 카탈로그에서 실제 선택 가능한 액션 목록을 돌려준다.
    ///
    /// "준비 중" 액션은 넣지 않는다 — 이 액션의 목적이 사용 가능한 것만
    /// 알려주는 것이므로, 미구현을 섞으면 목록 자체가 거짓말이 된다.
    static func listActions() -> Outcome {
        let lines = ActionType.catalogVisible
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            .map { "\($0.displayName) (\($0.rawValue))" }
        return .success(lines.joined(separator: "\n"))
    }

    // MARK: - 출력 저장

    /// 텍스트를 파일로 저장한다. 경로가 폴더면 `output.txt`를 붙인다.
    ///
    /// 상위 폴더는 만들어 준다 — 사용자가 경로를 직접 입력하는 액션이라
    /// "폴더가 없어서 실패"는 불필요한 마찰이다. 덮어쓰기/덧붙이기는
    /// `append`로 명시한다(기본 덮어쓰기).
    static func saveOutput(
        _ text: String,
        to path: String,
        append: Bool,
        fileManager: FileManager = .default
    ) -> Outcome {
        let raw = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return .failure(.emptyPath) }

        let expanded = (raw as NSString).expandingTildeInPath
        var url = URL(fileURLWithPath: expanded)
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            url = url.appendingPathComponent("output.txt")
        }

        do {
            let parent = url.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: parent,
                withIntermediateDirectories: true
            )
            guard let data = text.data(using: .utf8) else {
                return .failure(.saveFailed(url.path))
            }
            if append, fileManager.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: url, options: .atomic)
            }
            return .success(url.path)
        } catch {
            return .failure(.saveFailed(error.localizedDescription))
        }
    }
}
