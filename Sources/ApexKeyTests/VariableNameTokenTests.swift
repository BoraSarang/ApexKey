import Foundation
import XCTest
@testable import ApexKey

/// T-223 사용자 변수 이름 토큰 `{이름}` 검증.
///
/// UUID 토큰(`{UUID}`)은 그대로 동작해야 하고, 같은 이름의 특수 변수가 있으면
/// 특수 변수가 우선한다. 값이 없는 변수는 빈 문자열이 된다.
final class VariableNameTokenTests: XCTestCase {

    private func context(
        names: [String: UUID] = [:],
        values: [UUID: VariableValue] = [:],
        repeatIndex: Int? = nil
    ) -> VariableResolver.ResolveContext {
        var ctx = VariableResolver.ResolveContext()
        ctx.variableNames = names
        ctx.variables = values
        ctx.repeatIndex = repeatIndex
        return ctx
    }

    // MARK: - VariableResolver

    func testNameTokenResolvesUserVariable() {
        let id = UUID()
        let ctx = context(names: ["greeting": id], values: [id: .text("안녕")])
        XCTAssertEqual(
            VariableResolver.resolveText("값: {greeting}!", context: ctx),
            "값: 안녕!"
        )
    }

    func testNameTokenResolvesMultipleOccurrences() {
        let id = UUID()
        let ctx = context(names: ["name": id], values: [id: .text("Apex")])
        XCTAssertEqual(
            VariableResolver.resolveText("{name}-{name}", context: ctx),
            "Apex-Apex"
        )
    }

    func testNameTokenWithNoValueBecomesEmpty() {
        let id = UUID()
        let ctx = context(names: ["empty": id])
        XCTAssertEqual(VariableResolver.resolveText("[{empty}]", context: ctx), "[]")
    }

    func testUnknownNameTokenIsLeftUntouched() {
        let ctx = context(names: ["known": UUID()])
        XCTAssertEqual(
            VariableResolver.resolveText("{unknown}", context: ctx),
            "{unknown}"
        )
    }

    func testSpecialVariableWinsOverSameName() {
        var ctx = context(
            names: ["repeatIndex": UUID()],
            values: [UUID(): .text("USER")],
            repeatIndex: 3
        )
        ctx.variables[ctx.variableNames["repeatIndex"]!] = .text("USER")
        XCTAssertEqual(
            VariableResolver.resolveText("{repeatIndex}", context: ctx),
            "3",
            "특수 변수 이름과 겹치면 특수 변수가 우선한다"
        )
    }

    func testUUIDTokenStillWorks() {
        let id = UUID()
        let ctx = context(values: [id: .text("by-id")])
        XCTAssertEqual(
            VariableResolver.resolveToken(id.uuidString, context: ctx),
            .text("by-id")
        )
    }

    func testResolveTokenUsesNameTable() {
        let id = UUID()
        let ctx = context(names: ["greeting": id], values: [id: .text("hello")])
        XCTAssertEqual(
            VariableResolver.resolveToken("{greeting}", context: ctx),
            .text("hello")
        )
    }

    func testShellEscapingStillAppliesToNameTokens() {
        let id = UUID()
        let ctx = context(names: ["name": id], values: [id: .text("a b")])
        let resolved = VariableResolver.resolveText(
            "{name}",
            context: ctx,
            escaping: { "\"\($0)\"" }
        )
        XCTAssertEqual(resolved, "\"a b\"")
    }

    // MARK: - 엔진 배선

    private func variable(named name: String, value: String) -> Variable {
        Variable(name: name, type: .manual, defaultValue: .text(value))
    }

    func testEngineRegistersShortcutVariableNames() {
        let variable = variable(named: "greeting", value: "안녕")
        let step = ShortcutStep(
            type: .text,
            target: "",
            title: "",
            actionParameters: try? JSONEncoder().encode(TextActionConfig(text: "{greeting}, 세계"))
        )
        let shortcut = ShortcutItem(name: "이름 토큰", steps: [step], variables: [variable])

        var context = UseModelExecutor.ExecutionContext()
        context.variables[variable.id] = .text("안녕")
        let result = ExecutionEngine.shared.execute(shortcut, context: &context)

        XCTAssertTrue(result.success)
        XCTAssertEqual(context.stepOutputs[step.id], .text("안녕, 세계"))
        XCTAssertTrue(context.variableNames.isEmpty, "실행이 끝나면 이름 표를 되돌린다")
    }

    func testEngineIgnoresHiddenVariables() {
        let hidden = Variable(
            name: "secret",
            type: .manual,
            defaultValue: .text("x"),
            isHidden: true
        )
        let step = ShortcutStep(
            type: .text,
            target: "",
            title: "",
            actionParameters: try? JSONEncoder().encode(TextActionConfig(text: "{secret}"))
        )
        let shortcut = ShortcutItem(name: "숨김", steps: [step], variables: [hidden])

        var context = UseModelExecutor.ExecutionContext()
        _ = ExecutionEngine.shared.execute(shortcut, context: &context)
        XCTAssertEqual(
            context.stepOutputs[step.id],
            .text("{secret}"),
            "숨김 변수는 이름 토큰으로 노출하지 않는다"
        )
    }

    func testEngineRestoresOuterNamesAfterNestedShortcut() {
        let outer = variable(named: "outer", value: "A")
        let inner = variable(named: "inner", value: "B")

        let innerStep = ShortcutStep(
            type: .text,
            target: "",
            title: "",
            actionParameters: try? JSONEncoder().encode(TextActionConfig(text: "{inner}"))
        )
        let innerShortcut = ShortcutItem(name: "안쪽", steps: [innerStep], variables: [inner])
        ExecutionEngine.shared.shortcutProvider = { id in
            id == innerShortcut.id ? innerShortcut : nil
        }
        defer { ExecutionEngine.shared.shortcutProvider = nil }

        let runStep = ShortcutStep(type: .runShortcut, target: innerShortcut.id.uuidString, title: "")
        let outerShortcut = ShortcutItem(name: "바깥", steps: [runStep], variables: [outer])

        var context = UseModelExecutor.ExecutionContext()
        context.variables[inner.id] = .text("B")
        let result = ExecutionEngine.shared.execute(outerShortcut, context: &context)

        XCTAssertTrue(result.success)
        XCTAssertEqual(context.stepOutputs[innerStep.id], .text("B"))
        XCTAssertNil(context.variableNames["inner"], "중첩 단축어 이름이 바깥으로 새지 않는다")
        XCTAssertTrue(context.variableNames.isEmpty)
    }
}
