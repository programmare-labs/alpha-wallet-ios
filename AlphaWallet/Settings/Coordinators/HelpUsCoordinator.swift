// Copyright SIX DAY LLC. All rights reserved.
import Foundation
import UIKit
import StoreKit

class HelpUsCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let appTracker: AppTracker
    private let viewModel = HelpUsViewModel()
    private let analyticsCoordinator: AnalyticsCoordinator

    var coordinators: [Coordinator] = []

    init(
        navigationController: UINavigationController = UINavigationController(),
        appTracker: AppTracker = AppTracker(),
        analyticsCoordinator: AnalyticsCoordinator
    ) {
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.appTracker = appTracker
        self.analyticsCoordinator = analyticsCoordinator
    }

    func start() {
        switch appTracker.launchCountForCurrentBuild {
        case 6 where !appTracker.completedRating:
            rateUsOrSubscribeToNewsletter()
        case 12 where !appTracker.completedSharing:
            wellDone()
        default: break
        }
    }

    func rateUsOrSubscribeToNewsletter() {
        if Features.isPromptForEmailListSubscriptionEnabled && appTracker.launchCountForCurrentBuild > 3 && !appTracker.hasCompletedPromptForNewsletter {
            promptSubscribeToNewsletter()
        } else {
            rateUs()
        }
    }

    private func promptSubscribeToNewsletter() {
        guard !appTracker.hasCompletedPromptForNewsletter else { return }
        appTracker.hasCompletedPromptForNewsletter = true

        let controller = CollectUsersEmailViewController()
        controller._delegate = self
        controller.configure(viewModel: .init())

        navigationController.present(controller, animated: true)
    }

    private func rateUs() {
        SKStoreReviewController.requestReview()
        appTracker.completedRating = true
    }

    private func wellDone() {
        let controller = WellDoneViewController()
        controller.navigationItem.title = viewModel.title
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.done(), style: .done, target: self, action: #selector(dismiss))
        controller.delegate = self
        let nav = UINavigationController(rootViewController: controller)
        nav.makePresentationFullScreenForiOS13Migration()
        navigationController.present(nav, animated: true, completion: nil)
    }

    @objc private func dismiss() {
        navigationController.dismiss(animated: true, completion: nil)
    }

    func presentSharing(in viewController: UIViewController, from sender: UIView) {
        let activityViewController = UIActivityViewController(
            activityItems: viewModel.activityItems,
            applicationActivities: nil
        )
        activityViewController.popoverPresentationController?.sourceView = sender
        activityViewController.popoverPresentationController?.sourceRect = sender.centerRect
        viewController.present(activityViewController, animated: true, completion: nil)
    }
}

extension HelpUsCoordinator: CollectUsersEmailViewControllerDelegate {
    func didClose(in viewController: CollectUsersEmailViewController) {
        logEmailNewsletterSubscription(isSubscribed: false)
    }

    func didFinish(in viewController: CollectUsersEmailViewController, email: String) {
        if email.isEmpty {
            logEmailNewsletterSubscription(isSubscribed: false)
        } else {
            EmailList(listSpecificKey: Constants.Credentials.mailChimpListSpecificKey).subscribe(email: email)
            logEmailNewsletterSubscription(isSubscribed: true)
        }
    }
}

extension HelpUsCoordinator: WellDoneViewControllerDelegate {
    func didPress(action: WellDoneAction, sender: UIView, in viewController: WellDoneViewController) {
        switch action {
        case .other:
            presentSharing(in: viewController, from: sender)
        }

        appTracker.completedSharing = true
    }
}

// MARK: Analytics
extension HelpUsCoordinator {
    private func logEmailNewsletterSubscription(isSubscribed: Bool) {
        analyticsCoordinator.log(action: Analytics.Action.subscribeToEmailNewsletter, properties: [Analytics.Properties.isAccepted.rawValue: isSubscribed])
    }
}
