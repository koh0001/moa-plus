import XCTest

/// Tests for `KeyboardViewModel.resolveVowelFromPrimitiveDrag` (PR G6, G11, G14).
/// Covers single-stroke base vowels and multi-stroke compound vowels on the
/// ㅣ (`.bar`) and ㅡ (`.dash`) primitive keys.
final class KeyboardViewModelVowelDragTests: XCTestCase {

    var vm: KeyboardViewModel!

    override func setUp() {
        super.setUp()
        vm = KeyboardViewModel()
    }

    override func tearDown() {
        vm = nil
        super.tearDown()
    }

    // MARK: - Multi-stroke vowel drag (PR G14)

    func test_dashUpRight_yieldsWa() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up, .right]), .ㅘ)
    }

    func test_dashUpRightLeft_yieldsWae() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up, .right, .left]), .ㅙ)
    }

    func test_dashUpLeft_yieldsOe() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up, .left]), .ㅚ)
    }

    func test_dashDownLeft_yieldsWeo() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.down, .left]), .ㅝ)
    }

    func test_dashDownLeftRight_yieldsWe() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.down, .left, .right]), .ㅞ)
    }

    func test_dashDownRight_yieldsWi() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.down, .right]), .ㅟ)
    }

    func test_barLeftRight_yieldsE() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.left, .right]), .ㅔ)
    }

    func test_barRightLeft_yieldsAe() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.right, .left]), .ㅐ)
    }

    func test_barUpRight_yieldsYe() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.up, .right]), .ㅖ)
    }

    func test_barUpLeft_yieldsYe() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.up, .left]), .ㅖ)
    }

    func test_barDownRight_yieldsYae() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.down, .right]), .ㅒ)
    }

    func test_barDownLeft_yieldsYae() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.down, .left]), .ㅒ)
    }

    // MARK: - Diagonal first stroke normalization (PR G14)

    func test_dashUpRightDiagonal_normalizesToUp() {
        // First stroke ↗ should normalize to ↑ → ㅗ
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.upRight]), .ㅗ)
    }

    func test_dashUpRightDiagonalThenRight_yieldsWa() {
        // ↗ → ㅗ, then → → ㅘ
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.upRight, .right]), .ㅘ)
    }

    // MARK: - Single-stroke regression (PR G6)

    func test_barLeft_stillYieldsEo() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.left]), .ㅓ)
    }

    func test_barRight_stillYieldsA() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.right]), .ㅏ)
    }

    func test_barUp_stillYieldsYeo() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.up]), .ㅕ)
    }

    func test_barDown_stillYieldsYa() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.down]), .ㅑ)
    }

    func test_dashUp_stillYieldsO() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up]), .ㅗ)
    }

    func test_dashDown_stillYieldsU() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.down]), .ㅜ)
    }

    func test_dashLeft_stillYieldsYo() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.left]), .ㅛ)
    }

    func test_dashRight_stillYieldsYu() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.right]), .ㅠ)
    }

    // MARK: - Edge cases

    func test_emptyDirections_yieldsNil() {
        XCTAssertNil(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: []))
        XCTAssertNil(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: []))
    }

    func test_dotPrimitive_alwaysYieldsNil() {
        XCTAssertNil(vm.resolveVowelFromPrimitiveDrag(primitive: .dot, directions: [.up]))
        XCTAssertNil(vm.resolveVowelFromPrimitiveDrag(primitive: .dot, directions: [.up, .right]))
    }

    func test_secondStrokeNoCompound_keepsPriorVowel() {
        // ㅏ has no compound for `.right`; should remain ㅏ.
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.right, .right]), .ㅏ)
        // ㅗ + ↑ has no compound; should remain ㅗ.
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up, .up]), .ㅗ)
    }
}
