import XCTest
import CoreGraphics

/// Phase 1 (per-side sector widths) tests.
///
/// Adds `leftHalfWidth` / `rightHalfWidth` to `DirectionSector` (default =
/// `halfWidth` = 22.5 → symmetric, identical to legacy) and a global
/// `axisRotation` to `SwipeProfile`. The recognition core (`GestureDirection.from`)
/// gains a per-side claim + a two-step resolver that lets a user-widened
/// cardinal win over an adjacent diagonal, while preserving diagonal-first
/// priority inside the base 22.5° range (per-column behaviour intact).
final class PerSideSectorWidthTests: XCTestCase {

    // Sign convention: signedAngularDistance(center, relative) positive = CCW =
    // left half → leftHalfWidth; negative = CW = right half → rightHalfWidth.
    //
    // Helper: build a vector at a math-convention angle (0°=→, 90°=↑) with the
    // iOS y-axis inverted so the engine reads it back as that same angle.
    private func vector(atDegrees deg: Double, length: Double = 100) -> CGVector {
        let r = deg * .pi / 180
        return CGVector(dx: cos(r) * length, dy: -sin(r) * length)
    }

    // MARK: - (a) default equivalence: left=right=22.5 reproduces legacy

    func testDefaultSectorsHaveSymmetricPerSideWidths() {
        for sector in DirectionSector.defaultSectors {
            XCTAssertEqual(sector.leftHalfWidth, sector.halfWidth, accuracy: 1e-9,
                           "기본 leftHalfWidth 는 halfWidth(22.5) 와 같아야 한다")
            XCTAssertEqual(sector.rightHalfWidth, sector.halfWidth, accuracy: 1e-9,
                           "기본 rightHalfWidth 는 halfWidth(22.5) 와 같아야 한다")
        }
    }

    func testDefaultEightWayClassificationUnchanged() {
        let sectors = DirectionSector.defaultSectors
        func dir(_ deg: Double) -> GestureDirection? {
            GestureDirection.from(vector: vector(atDegrees: deg),
                                  sectors: sectors, rotationOffset: 0, threshold: 20)
        }
        // Cardinal centers and diagonal centers all classify as before.
        XCTAssertEqual(dir(0), .right)
        XCTAssertEqual(dir(45), .upRight)
        XCTAssertEqual(dir(90), .up)
        XCTAssertEqual(dir(135), .upLeft)
        XCTAssertEqual(dir(180), .left)
        XCTAssertEqual(dir(225), .downLeft)
        XCTAssertEqual(dir(270), .down)
        XCTAssertEqual(dir(315), .downRight)
        // 30° sits inside ↗ base (45±22.5 = 22.5…67.5) → diagonal-first ↗.
        XCTAssertEqual(dir(30), .upRight, "30° 은 기본에서 ↗ (diagonal-first 보존)")
        // 60° likewise inside ↗ base → ↗ (this is what a widened ↑ will later flip).
        XCTAssertEqual(dir(60), .upRight, "60° 은 기본에서 ↗")
    }

    // MARK: - STEP1 tie-break: equal widened distance → earlier cardinal index

    func testWidenedCardinalTieBreakFavorsEarlierCardinalIndex() {
        // → (index 0, center 0) widened on its CCW(left) side; ↑ (index 2,
        // center 90) widened on its CW(right) side. At 45° both are exactly 45°
        // from center and both claim via STEP1 (22.5 < 45 <= 50). The strict-`<`
        // tie-break keeps the first in cardinalSectorIndices order [0,2,4,6] → →.
        var sectors = DirectionSector.defaultSectors
        sectors[0].leftHalfWidth = 50
        sectors[2].rightHalfWidth = 50
        let result = GestureDirection.from(vector: vector(atDegrees: 45),
                                           sectors: sectors, rotationOffset: 0, threshold: 20)
        XCTAssertEqual(result, .right,
                       "동률(45°)이면 cardinalSectorIndices 순서로 → 가 우선")
    }

    // MARK: - (c) new ability: widened cardinal beats adjacent diagonal

    func testWidenedCardinalUpRightSideBeatsDiagonalAt60() {
        var sectors = DirectionSector.defaultSectors
        // ↑ is index 2, centerAngle 90. 60° is CW of 90 → right side.
        sectors[2].rightHalfWidth = 35
        let result = GestureDirection.from(vector: vector(atDegrees: 60),
                                           sectors: sectors, rotationOffset: 0, threshold: 20)
        XCTAssertEqual(result, .up,
                       "↑ 우측 35° 확대 시 60° 는 ↑ (|60-90|=30: base 22.5 초과, 35 이하 → STEP1 우선)")
    }

    func testWidenedCardinalDoesNotLeakBelowBase() {
        var sectors = DirectionSector.defaultSectors
        sectors[2].rightHalfWidth = 35
        // 75° is |75-90|=15 < base 22.5 → still inside ↑ base, classifies ↑ regardless.
        let r75 = GestureDirection.from(vector: vector(atDegrees: 75),
                                        sectors: sectors, rotationOffset: 0, threshold: 20)
        XCTAssertEqual(r75, .up, "75° 는 ↑ base 안 → ↑")
        // 67.5° boundary: inside ↗ base AND inside widened ↑ (|67.5-90|=22.5 = base,
        // not > base) → STEP1 not triggered, diagonal-first STEP2 gives ↗.
        let r67 = GestureDirection.from(vector: vector(atDegrees: 67.5),
                                        sectors: sectors, rotationOffset: 0, threshold: 20)
        XCTAssertEqual(r67, .upRight,
                       "67.5° 는 ↑ widening 경계와 같음(>base 아님) → diagonal-first ↗ 보존")
    }

    func testLeftSideWidthIsIndependentOfRightSide() {
        var sectors = DirectionSector.defaultSectors
        // Widen ↑ left side only (CCW, toward ↖). 120° is CCW of 90 (|120-90|=30).
        sectors[2].leftHalfWidth = 35
        let left = GestureDirection.from(vector: vector(atDegrees: 120),
                                         sectors: sectors, rotationOffset: 0, threshold: 20)
        XCTAssertEqual(left, .up, "↑ 좌측 35° 확대 → 120° 는 ↑ (좌측 독립)")
        // Right side untouched (base 22.5): 60° stays ↗.
        let right = GestureDirection.from(vector: vector(atDegrees: 60),
                                          sectors: sectors, rotationOffset: 0, threshold: 20)
        XCTAssertEqual(right, .upRight, "우측은 base 그대로 → 60° 는 ↗")
    }

    func testNearestWidenedCardinalWinsOnConflict() {
        var sectors = DirectionSector.defaultSectors
        // Widen → (index 0, center 0) left side and ↑ (index 2, center 90) right side
        // both into the ↗ diagonal. 50° is |50-0|=50 (→) vs |50-90|=40 (↑).
        sectors[0].leftHalfWidth = 55   // → left side reaches up to 55°
        sectors[2].rightHalfWidth = 45  // ↑ right side reaches down to 45°
        let result = GestureDirection.from(vector: vector(atDegrees: 50),
                                           sectors: sectors, rotationOffset: 0, threshold: 20)
        XCTAssertEqual(result, .up, "두 확대 충돌 시 center 에 가까운 쪽(↑, 40<50) 우선")
    }

    // MARK: - STEP3 nearest-center fallback (dead-zone removal)
    //
    // Narrowing one side of a sector opens a gap between it and its neighbour.
    // Pre-fix the resolver returned nil there (a dead zone — the user's swipe
    // was silently dropped). STEP3 assigns any unclaimed angle to the sector
    // whose center is closest, so a narrowed direction never produces a dead
    // zone. Rule (user-confirmed): "넓히면 뺏고, 좁힌 빈곳은 가장 가까운 방향".

    func testNarrowedSideGapFallsBackToNearestCenter() {
        var sectors = DirectionSector.defaultSectors
        // ↗ (index 1, center 45): narrow CCW(left, toward ↑) to 14°, widen
        // CW(right, toward →) to 40° — the exact config the user reported.
        sectors[1].leftHalfWidth = 14
        sectors[1].rightHalfWidth = 40
        // 63° sits in the gap [59, 67.5] between ↗'s narrowed left edge (45+14)
        // and ↑'s base right edge (90-22.5). Pre-fix → nil (dead zone). STEP3:
        // |63-45|=18 (↗) < |63-90|=27 (↑) → nearest center is ↗.
        let result = GestureDirection.from(vector: vector(atDegrees: 63),
                                           sectors: sectors, rotationOffset: 0, threshold: 20)
        XCTAssertEqual(result, .upRight,
                       "좁힌 빈구역(63°)은 가장 가까운 center ↗ 로 배정 — 데드존 0")
    }

    func testGapSplitsBetweenNarrowedNeighborsByNearestCenter() {
        var sectors = DirectionSector.defaultSectors
        // Narrow both ↗'s left (edge → 55°) and ↑'s right (edge → 80°).
        // gap [55, 80]; nearest-center boundary is the midpoint of the two
        // centers, 67.5°.
        sectors[1].leftHalfWidth = 10
        sectors[2].rightHalfWidth = 10
        // 70° past midpoint → nearer ↑ (|70-90|=20 < |70-45|=25).
        let nearUp = GestureDirection.from(vector: vector(atDegrees: 70),
                                           sectors: sectors, rotationOffset: 0, threshold: 20)
        XCTAssertEqual(nearUp, .up, "gap 의 ↑쪽 절반(70°)은 가장 가까운 ↑ 로")
        // 60° before midpoint → nearer ↗ (|60-45|=15 < |60-90|=30).
        let nearUpRight = GestureDirection.from(vector: vector(atDegrees: 60),
                                                sectors: sectors, rotationOffset: 0, threshold: 20)
        XCTAssertEqual(nearUpRight, .upRight, "gap 의 ↗쪽 절반(60°)은 가장 가까운 ↗ 로")
    }

    func testNoDeadZoneAcrossFullSweepWithNarrowedSides() {
        var sectors = DirectionSector.defaultSectors
        sectors[1].leftHalfWidth = 14   // user's reported ↗ config
        sectors[1].rightHalfWidth = 40
        sectors[3].leftHalfWidth = 8    // also narrow ↖ to stress more gaps
        var deg = 0.0
        while deg < 360 {
            let result = GestureDirection.from(vector: vector(atDegrees: deg),
                                               sectors: sectors, rotationOffset: 0, threshold: 20)
            XCTAssertNotNil(result, "\(deg)° 에서 nil(데드존) 이 없어야 한다")
            deg += 0.5
        }
    }

    func testDefaultSweepNeverReachesFallback() {
        // Default sectors fully tile 360° via STEP2 (left==right==22.5), so the
        // STEP3 fallback must never fire — every angle is claimed identically to
        // pre-fix. Guards against the fallback silently altering legacy output.
        let sectors = DirectionSector.defaultSectors
        var deg = 0.0
        while deg < 360 {
            let result = GestureDirection.from(vector: vector(atDegrees: deg),
                                               sectors: sectors, rotationOffset: 0, threshold: 20)
            XCTAssertNotNil(result, "기본 섹터는 전 각도 claim — \(deg)°")
            deg += 0.5
        }
    }

    // MARK: - (e) wrap-safety around 0°/360°

    func testWrapAroundRightDirection() {
        let sectors = DirectionSector.defaultSectors
        for deg in [0.0, 359.0, 1.0, 360.0] {
            let result = GestureDirection.from(vector: vector(atDegrees: deg),
                                               sectors: sectors, rotationOffset: 0, threshold: 20)
            XCTAssertEqual(result, .right, "\(deg)° 는 → 로 분류 (wrap-safe)")
        }
    }

    func testWidenedRightWrapsAcrossZero() {
        var sectors = DirectionSector.defaultSectors
        // → is index 0, center 0. Widen right side (CW = toward 315/↘).
        sectors[0].rightHalfWidth = 35
        // 330° → signed dist from 0 = -30 (CW, right side). base 22.5 < 30 <= 35 → →.
        let result = GestureDirection.from(vector: vector(atDegrees: 330),
                                           sectors: sectors, rotationOffset: 0, threshold: 20)
        XCTAssertEqual(result, .right, "→ 우측 35° 확대 + wrap: 330° 는 → (STEP1, CW=right)")
    }

    func testRotationOffsetWithPerSideStillResolves() {
        var sectors = DirectionSector.defaultSectors
        sectors[2].rightHalfWidth = 35
        // With rotationOffset +20, the incoming vector is rotated; a raw 80° vector
        // becomes relative 60° → widened ↑ should still claim it.
        let result = GestureDirection.from(vector: vector(atDegrees: 80),
                                           sectors: sectors, rotationOffset: 20, threshold: 20)
        XCTAssertEqual(result, .up,
                       "rotationOffset +20 적용 후 relative 60° → 확대 ↑ 가 claim")
    }

    // MARK: - (d) four-way path unchanged

    func testFourWayPathIgnoresPerSideWidths() {
        var sectors = DirectionSector.defaultSectors
        sectors[2].rightHalfWidth = 40  // would matter in 8-way, ignored in 4-way
        // 30° in four-way snaps to nearest cardinal → (|30-0|=30 < |30-90|=60).
        let result = GestureDirection.from(vector: vector(atDegrees: 30),
                                           sectors: sectors, rotationOffset: 0,
                                           threshold: 20, fourWay: true)
        XCTAssertEqual(result, .right, "4방향 경로는 per-side 무시, 가까운 카디널 → 로 스냅")
    }

    // MARK: - applyingDiagonalDeltas: shared widen helper (engine ↔ pie parity)
    //
    // The recogniser (`GestureAnalyzer.effectiveSectors`) and every settings
    // pie chart must widen diagonal sectors the SAME way: add the ㅣ/ㅡ column
    // delta to BOTH per-side widths, never touching `halfWidth` (whose didSet
    // mirror-resets the sides and silently destroys a user's left/right
    // asymmetry — the root cause of the "편집 파이 ↔ 매핑 파이 불일치" report).

    func testApplyingDiagonalDeltasPreservesAsymmetry() {
        var sectors = DirectionSector.defaultSectors
        sectors[1].leftHalfWidth = 14    // ↗ asymmetric (user's reported config)
        sectors[1].rightHalfWidth = 40
        let out = sectors.applyingDiagonalDeltas(iDelta: 5, euDelta: 0)
        XCTAssertEqual(out[1].leftHalfWidth, 19, accuracy: 1e-9, "왼쪽 14+5=19, 비대칭 보존")
        XCTAssertEqual(out[1].rightHalfWidth, 45, accuracy: 1e-9, "오른쪽 40+5=45, 비대칭 보존")
        XCTAssertEqual(out[1].halfWidth, 22.5, accuracy: 1e-9,
                       "halfWidth 는 건드리지 않음 (didSet 미발동)")
    }

    func testApplyingZeroDeltasIsNoOp() {
        var sectors = DirectionSector.defaultSectors
        sectors[1].leftHalfWidth = 14
        sectors[1].rightHalfWidth = 40
        sectors[3].leftHalfWidth = 8
        let out = sectors.applyingDiagonalDeltas(iDelta: 0, euDelta: 0)
        XCTAssertEqual(out, sectors,
                       "delta 0 은 no-op — 매핑 파이가 편집 파이와 동일한 per-side 폭을 그린다")
    }

    func testApplyingDiagonalDeltasMapsCorrectDiagonalIndices() {
        let out = DirectionSector.defaultSectors.applyingDiagonalDeltas(iDelta: 5, euDelta: 3)
        // ↗(1)/↖(3) widen with ㅣ delta; ↙(5)/↘(7) with ㅡ delta; cardinals untouched.
        XCTAssertEqual(out[1].leftHalfWidth, 27.5, accuracy: 1e-9)  // 22.5+5
        XCTAssertEqual(out[3].rightHalfWidth, 27.5, accuracy: 1e-9)
        XCTAssertEqual(out[5].leftHalfWidth, 25.5, accuracy: 1e-9)  // 22.5+3
        XCTAssertEqual(out[7].rightHalfWidth, 25.5, accuracy: 1e-9)
        XCTAssertEqual(out[0].leftHalfWidth, 22.5, accuracy: 1e-9, "→ 카디널 불변")
        XCTAssertEqual(out[2].rightHalfWidth, 22.5, accuracy: 1e-9, "↑ 카디널 불변")
    }

    // MARK: - Codable: legacy (no fields) round-trips symmetric

    func testLegacyDirectionSectorJSONDecodesSymmetric() throws {
        let json = Data(#"{"centerAngle":90,"halfWidth":30}"#.utf8)
        let sector = try JSONDecoder().decode(DirectionSector.self, from: json)
        XCTAssertEqual(sector.centerAngle, 90)
        XCTAssertEqual(sector.halfWidth, 30)
        XCTAssertEqual(sector.leftHalfWidth, 30, "구버전 JSON: leftHalfWidth = halfWidth")
        XCTAssertEqual(sector.rightHalfWidth, 30, "구버전 JSON: rightHalfWidth = halfWidth")
    }

    func testNewDirectionSectorRoundTrips() throws {
        var sector = DirectionSector(centerAngle: 90)
        sector.leftHalfWidth = 35
        sector.rightHalfWidth = 18
        let data = try JSONEncoder().encode(sector)
        let decoded = try JSONDecoder().decode(DirectionSector.self, from: data)
        XCTAssertEqual(decoded, sector, "신규 per-side 값이 round-trip 보존되어야 한다")
        XCTAssertEqual(decoded.leftHalfWidth, 35)
        XCTAssertEqual(decoded.rightHalfWidth, 18)
    }

    func testLegacySwipeProfileJSONDefaultsAxisRotationToZero() throws {
        let json = Data("""
        {"mode":"both","swipeLength":"normal",
         "sectors":[{"centerAngle":0,"halfWidth":22.5}],
         "upLeftMapping":"vowelI","upRightMapping":"vowelI",
         "downLeftMapping":"vowelEu","downRightMapping":"vowelEu"}
        """.utf8)
        let profile = try JSONDecoder().decode(SwipeProfile.self, from: json)
        XCTAssertEqual(profile.axisRotation, 0, "구버전 JSON 은 axisRotation 0 기본")
        XCTAssertEqual(profile.sectors.first?.leftHalfWidth, 22.5,
                       "구버전 sectors 의 per-side 는 대칭 디코딩")
        XCTAssertEqual(profile.sectors.first?.rightHalfWidth, 22.5)
    }

    func testNewSwipeProfileAxisRotationRoundTrips() throws {
        var profile = SwipeProfile()
        profile.axisRotation = 12.5
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(SwipeProfile.self, from: data)
        XCTAssertEqual(decoded.axisRotation, 12.5, "axisRotation round-trip 보존")
    }
}
