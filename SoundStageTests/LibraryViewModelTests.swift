import XCTest
@testable import SoundStage

@MainActor
final class LibraryViewModelTests: XCTestCase {

    func testAuthorizedLoadsTracks() async {
        let mock = MockLibraryProvider(status: .authorized, songs: [.stub(id: "1"), .stub(id: "2")])
        let viewModel = LibraryViewModel(service: mock)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(viewModel.tracks.count, 2)
    }

    func testAuthorizedButEmptyShowsEmptyState() async {
        let mock = MockLibraryProvider(status: .authorized, songs: [])
        let viewModel = LibraryViewModel(service: mock)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.state, .empty)
        XCTAssertTrue(viewModel.tracks.isEmpty)
    }

    func testDeniedShowsAccessDenied() async {
        let mock = MockLibraryProvider(status: .denied, songs: [.stub(id: "1")])
        let viewModel = LibraryViewModel(service: mock)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.state, .accessDenied)
        XCTAssertTrue(viewModel.tracks.isEmpty)
    }

    func testNotDeterminedThenGrantedLoads() async {
        let mock = MockLibraryProvider(status: .notDetermined, songs: [.stub(id: "1")], requestResult: .authorized)
        let viewModel = LibraryViewModel(service: mock)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(viewModel.tracks.count, 1)
    }

    func testNotDeterminedThenDeniedShowsAccessDenied() async {
        let mock = MockLibraryProvider(status: .notDetermined, songs: [.stub(id: "1")], requestResult: .denied)
        let viewModel = LibraryViewModel(service: mock)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.state, .accessDenied)
    }

    func testSearchFiltersByTitleAndArtist() async {
        let mock = MockLibraryProvider(status: .authorized, songs: [
            .stub(id: "1", title: "Midnight City", artist: "M83"),
            .stub(id: "2", title: "Strobe", artist: "deadmau5")
        ])
        let viewModel = LibraryViewModel(service: mock)
        await viewModel.loadIfNeeded()

        viewModel.searchText = "strobe"
        XCTAssertEqual(viewModel.visibleTracks.map(\.id), ["2"])

        viewModel.searchText = "m8"
        XCTAssertEqual(viewModel.visibleTracks.map(\.id), ["1"])

        viewModel.searchText = "   "
        XCTAssertEqual(viewModel.visibleTracks.count, 2)
    }
}
