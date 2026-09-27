import SwiftUI
import UIKit

/// The real iBooks-style page curl - `UIPageViewController(transitionStyle: .pageCurl)`.
/// SwiftUI has no equivalent transition, so this wraps just enough UIKit to
/// get it, with swipe-forward AND swipe-back both working for free via
/// `UIPageViewController`'s data source (before/after controllers).
struct PageCurlView: UIViewControllerRepresentable {
    let cards: [ContactCard]
    @Binding var currentIndex: Int
    let insight: (ContactCard) -> String?
    let isSelf: (ContactCard) -> Bool
    let onDisplay: (ContactCard) -> Void
    // Optional: nil hides the Maya button in ContactCardView entirely,
    // rather than just making it inert - see CardFeedView's call site.
    let onMaya: (() -> Void)?
    let onShare: (ContactCard) -> Void

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageVC = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal
        )
        // The page surface must be opaque, but it also needs a rendered back
        // face. With this disabled, UIKit uses a blank white reverse side,
        // which is the white sheet visible during the curl.
        pageVC.isDoubleSided = true
        pageVC.dataSource = context.coordinator
        pageVC.delegate = context.coordinator
        pageVC.view.backgroundColor = .systemBackground
        if let initial = context.coordinator.controller(for: currentIndex) {
            pageVC.setViewControllers([initial], direction: .forward, animated: false)
        }
        return pageVC
    }

    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
        context.coordinator.parent = self

        let visibleIndex = pageVC.viewControllers?.first.flatMap(context.coordinator.index(of:))
        // Insight is loaded after the page is initially displayed. Refresh the
        // visible hosting controller even when the page index did not change;
        // otherwise the page-curl container keeps the original nil insight
        // forever.
        if visibleIndex == currentIndex,
           let host = pageVC.viewControllers?.first as? UIHostingController<AnyView>,
           let card = cards[safe: currentIndex] {
            host.rootView = AnyView(
                ContactCardView(card: card, insight: insight(card), isSelf: isSelf(card), onMaya: onMaya, onShare: onShare)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            )
            host.view.setNeedsLayout()
            return
        }
        guard visibleIndex != currentIndex else { return }
        guard let target = context.coordinator.controller(for: currentIndex) else { return }

        let direction: UIPageViewController.NavigationDirection =
            currentIndex > (visibleIndex ?? currentIndex) ? .forward : .reverse
        pageVC.setViewControllers([target], direction: direction, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageCurlView

        init(_ parent: PageCurlView) {
            self.parent = parent
        }

        /// UIPageViewController expects a freshly-built controller for a
        /// given position on every data-source call - it does its own
        /// caching/lifecycle management, so this intentionally doesn't
        /// memoize. `view.tag` carries the card index so the delegate
        /// callbacks below can report which page landed.
        func controller(for index: Int) -> UIViewController? {
            guard parent.cards.indices.contains(index) else { return nil }
            let card = parent.cards[index]
            let host = UIHostingController(
                rootView: AnyView(ContactCardView(card: card, insight: parent.insight(card), isSelf: parent.isSelf(card), onMaya: parent.onMaya, onShare: parent.onShare)
                    .padding(.horizontal, 16)
                    .padding(.top, 8))
            )
            // Keep the hosted page opaque during the curl. The SwiftUI root
            // supplies the app gradient; this UIKit background is only a
            // fallback for the brief moment before SwiftUI has rendered.
            host.view.backgroundColor = .systemBackground
            host.view.isOpaque = true
            host.view.tag = index
            // Let UIPageViewController provide the page's real bounds. A
            // screen-sized frame is wrong on iPad split view, rotation, and
            // inside the feed's header/action-bar layout, and can make the
            // hosted SwiftUI view render outside the visible page.
            host.view.translatesAutoresizingMaskIntoConstraints = true
            host.view.layoutIfNeeded()
            return host
        }

        func index(of controller: UIViewController) -> Int? {
            controller.view.tag
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let idx = index(of: viewController) else { return nil }
            return controller(for: idx - 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let idx = index(of: viewController) else { return nil }
            return controller(for: idx + 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed,
                  let visible = pageViewController.viewControllers?.first,
                  let idx = index(of: visible) else { return }
            parent.currentIndex = idx
            if parent.cards.indices.contains(idx) {
                parent.onDisplay(parent.cards[idx])
            }
        }

        /// Without this, `.pageCurl` style can switch into a 2-up "spread"
        /// (2 view controllers on screen at once, like an open book) on
        /// iPad's regular-width size class - `updateUIViewController`'s
        /// `setViewControllers` calls only ever provide 1, which crashes
        /// with "the number of view controllers provided (1) doesn't match
        /// the number required (2) for the requested transition" the moment
        /// that happens. Reported against a real iPad 2026-09-21. Forcing
        /// `.min` here keeps this a single-page-at-a-time feed always, which
        /// is what "flip through contact cards" actually wants.
        func pageViewController(
            _ pageViewController: UIPageViewController,
            spineLocationFor orientation: UIInterfaceOrientation
        ) -> UIPageViewController.SpineLocation {
            if let visible = pageViewController.viewControllers?.first {
                pageViewController.setViewControllers([visible], direction: .forward, animated: false, completion: nil)
            }
            return .min
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
