import AppKit

/// Menu HUD breadcrumb 드릴인 상태 (M-01) — 서브메뉴 제자리 전개 + 경로 점프백.
/// 순수 값 타입이라 단위 테스트 가능. 플로팅/오버레이 양쪽 뷰가 @State로 들고 쓴다.
struct MenuBrowsePath {
    private(set) var stack: [MenuItem] = []

    var isBrowsing: Bool { !stack.isEmpty }

    var currentChildren: [MenuItem]? { stack.last?.children }

    /// 서브메뉴 부모면 한 단계 진입. 잎 항목은 무시하고 false.
    @discardableResult
    mutating func drill(into item: MenuItem) -> Bool {
        guard item.isSubmenu else { return false }
        stack.append(item)
        return true
    }

    /// breadcrumb index 단계로 점프 (0 = 첫 서브메뉴까지 유지)
    mutating func jump(to index: Int) {
        guard index >= 0, index < stack.count else { return }
        stack = Array(stack.prefix(index + 1))
    }

    mutating func back() {
        _ = stack.popLast()
    }

    mutating func reset() {
        stack = []
    }
}

extension AppDelegate {
    /// 포인터 adjacent 프레임 계산 (M-01, 순수 함수).
    /// - 커서 오른쪽 + 아래(같은 높이 아래쪽) 우선, 공간 없으면 왼쪽/위쪽으로 뒤집는다.
    /// - 화면 visible 영역을 margin만큼 남기고 클램프한다 (다중모니터는 호출부의 screen(for:)가 담당).
    static func anchoredFrame(near point: NSPoint, size: NSSize, in visible: NSRect,
                              margin: CGFloat = 12, gap: CGFloat = 16) -> NSRect {
        var x = point.x + gap
        if x + size.width > visible.maxX - margin {
            x = point.x - size.width - gap
        }
        var y = point.y - size.height - gap
        if y < visible.minY + margin {
            y = point.y + gap + 8
        }
        x = min(max(x, visible.minX + margin), max(visible.minX + margin, visible.maxX - margin - size.width))
        y = min(max(y, visible.minY + margin), max(visible.minY + margin, visible.maxY - margin - size.height))
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
