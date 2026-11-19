import Foundation

/// 절대값 슬라이더 누적.
///
/// `base + travel`로 값을 계산하고 결과를 0...1로 자른다. 경계에서 더 밀어도
/// 이동분이 쌓이지 않도록 **자른 값 기준으로 travel을 다시 계산**한다.
/// (안 그러면 볼륨이 100%인 상태에서 더 밀었다가 반대로 밀 때 한참 동안 반응이 없다)
struct SliderValueAccumulator {
    let base: Float
    private(set) var travel: Float = 0

    init(base: Float) {
        self.base = min(max(base, 0), 1)
    }

    /// 이동량을 반영한 새 값(0...1)을 돌려준다.
    mutating func update(delta: Float) -> Float {
        let next = min(max(base + travel + delta, 0), 1)
        travel = next - base
        return next
    }
}
