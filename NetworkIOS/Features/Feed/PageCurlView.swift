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

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageVC = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal
        )
        pageVC.dataSource = context.coordinator
        pageVC.delegate = context.coordinator
        pageVC.view.backgroundColor = .clear
        pageVC.isDoubleSided = false
        if let initial = context.coordinator.controller(for: currentIndex) {
            pageVC.setViewControllers([initial], direction: .forward, animated: false)
        }
        return pageVC
    }

    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
        context.coordinator.parent = self

        let visibleIndex = pageVC.viewControllers?.first.flatMap(context.coordinator.index(of:))
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
                rootView: ContactCardView(card: card, insight: parent.insight(card), isSelf: parent.isSelf(card))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            )
            host.view.backgroundColor = .clear
            host.view.tag = index
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

        /// Without this, `.pageCurl` on a regular-width iPad (landscape)
        /// defaults to a two-page "open book" spine layout, which is why the
        /// card rendered narrower than the screen with a visible gap beside
        /// it — forcing `.min` keeps it a single full-width page in every
        /// orientation, matching iPhone.
        func pageViewController(
            _ pageViewController: UIPageViewController,
            spineLocationFor orientation: UIInterfaceOrientation
        ) -> UIPageViewController.SpineLocation {
            pageViewController.isDoubleSided = false
            return .min
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
    }
}
