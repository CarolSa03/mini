import UIKit

enum MainNavigationTransition: Int {
    case replace = 0
    case animateLeft = -1
    case animateRight = 1

    fileprivate func inOffset(container: UIView) -> CGFloat {
        return CGFloat(self.rawValue) * container.size.width
    }

    fileprivate func outOffset(container: UIView) -> CGFloat {
        return CGFloat(self.rawValue) * container.size.width * -1
    }

    func set(_ viewController: UIViewController, parent: MainNavigationContainer) {
        guard !viewController.isViewLoaded || viewController.view.superview != parent.container else { return }

        removeContainedViewControllers(parent: parent)
        addContainedViewController(viewController, parent: parent)
    }

    func run(dismissed: UIViewController, presented: UIViewController, parent: MainNavigationContainer, animated: Bool, completion: (() -> Void)?) {
        guard let container = parent.container else { return }

        if let propertyAnimator = parent.propertyAnimator, propertyAnimator.isRunning {
            propertyAnimator.stopAnimation(false)
            propertyAnimator.finishAnimation(at: .end)
        }

        dismissed.willMove(toParent: nil)
        dismissed.removeFromParent()
        dismissed.view.removeFromSuperview()

        presented.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(presented.view)
        let newLeftConstraint = addAnchorsToContainedView(presented.view, container: container, offset: inOffset(container: container))
        parent.container.layoutIfNeeded()

        parent.addChild(presented)

        newLeftConstraint?.constant = 0
        parent.leftMarginConstraint?.constant = outOffset(container: container)

        let transitionCompletionAction = {
            parent.leftMarginConstraint = newLeftConstraint
            presented.didMove(toParent: parent)
            completion?()

            parent.propertyAnimator = nil
        }

        if animated {
            let propertyAnimator = UIViewPropertyAnimator.runningPropertyAnimator(
                withDuration: Constants.Style.Animation.defaultDuration,
                delay: 0, options: .curveEaseInOut,
                animations: {
                    container.layoutIfNeeded()
                },
                completion: { _ in
                    transitionCompletionAction()
                }
            )

            parent.propertyAnimator = propertyAnimator
        } else {
            container.layoutIfNeeded()
            transitionCompletionAction()
        }
    }

    private func removeContainedViewControllers(parent: MainNavigationContainer) {
        let contained = parent.viewControllers.values.filter {
            $0.isViewLoaded && $0.view.superview == parent.container
        }

        contained.forEach {
            $0.willMove(toParent: nil)
            $0.removeFromParent()
            $0.view.removeFromSuperview()
        }
    }

    private func addContainedViewController(_ viewController: UIViewController, parent: MainNavigationContainer) {
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        parent.container.addSubview(viewController.view)
        parent.leftMarginConstraint = addAnchorsToContainedView(viewController.view, container: parent.container)
        parent.addChild(viewController)
        viewController.didMove(toParent: parent)
    }

    private func addAnchorsToContainedView(_ view: UIView, container: UIView, offset: CGFloat = 0) -> NSLayoutConstraint? {
        let constraints = [
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            view.widthAnchor.constraint(equalTo: container.widthAnchor),
            view.leftAnchor.constraint(equalTo: container.leftAnchor, constant: offset)
        ]
        NSLayoutConstraint.activate(constraints)
        return constraints.last
    }
}
