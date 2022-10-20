//
//  InAppPresentationManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

struct InAppMessageUIModel {
    struct InAppRedirect {
        let redirectUrl: URL?
        let payload: String
    }
    let inAppId: String
    let imageData: Data
    let redirect: InAppRedirect
}

protocol InAppPresentationManagerProtocol: AnyObject {
    func present(
        inAppFormData: InAppFormData,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onPresentationCompleted: @escaping () -> Void,
        onError: @escaping (InAppPresentationError) -> Void
    )
}

enum InAppPresentationError {
    case failedToLoadImages
}

typealias InAppMessageTapAction = (_ tapLink: URL?, _ payload: String) -> Void

/// Prepares UI for in-app messages and shows them
final class InAppPresentationManager: InAppPresentationManagerProtocol {

    init(imagesStorage: InAppImagesStorageProtocol) {
        self.imagesStorage = imagesStorage
    }

    private let imagesStorage: InAppImagesStorageProtocol
    private var inAppWindow: UIWindow?

    func present(
        inAppFormData: InAppFormData,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onPresentationCompleted: @escaping () -> Void,
        onError: @escaping (InAppPresentationError) -> Void
    ) {
        imagesStorage.getImage(url: inAppFormData.imageUrl, completionQueue: .main) { imageData in
            if let imageData = imageData {
                let redirectInfo = InAppMessageUIModel.InAppRedirect(
                    redirectUrl: URL(string: inAppFormData.redirectUrl),
                    payload: inAppFormData.intentPayload
                )

                let inAppUIModel = InAppMessageUIModel(
                    inAppId: inAppFormData.inAppId,
                    imageData: imageData,
                    redirect: redirectInfo
                )
                self.presentInAppUIModel(
                    inAppUIModel: inAppUIModel,
                    onPresented: onPresented,
                    onTapAction: onTapAction,
                    onPresentationCompleted: onPresentationCompleted
                )
            } else {
                onError(.failedToLoadImages)
                return
            }
        }
    }

    // MARK: - Private

    private func presentInAppUIModel(
        inAppUIModel: InAppMessageUIModel,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onPresentationCompleted: @escaping () -> Void
    ) {
        Log("Starting to present)")
            .category(.inAppMessages).level(.debug).make()

        let inAppWindow = makeInAppMessageWindow()

        let close: () -> Void = { [weak self] in
            self?.onClose(inApp: inAppUIModel, onPresentationCompleted)
        }
        let inAppViewController = InAppMessageViewController(
            inAppUIModel: inAppUIModel,
            onPresented: { [weak self] in
                self?.onPresented(inApp: inAppUIModel, onPresented)
            },
            onTapAction: { [weak self] in
                self?.onTapAction(inApp: inAppUIModel, onTap: onTapAction, close: close)
            },
            onClose: close
        )
        inAppWindow.rootViewController = inAppViewController
    }

    private func onPresented(inApp: InAppMessageUIModel, _ completion: @escaping () -> Void) {
        Log("InApp presented. Id: \(inApp.inAppId)")
            .category(.inAppMessages).level(.debug).make()
        //        Mindbox.shared.executeAsyncOperation(operationSystemName: <#T##String#>, json: <#T##String#>)
        completion()
    }

    private func onTapAction(
        inApp: InAppMessageUIModel,
        onTap: @escaping InAppMessageTapAction,
        close: @escaping () -> Void
    ) {
        let redirect = inApp.redirect
        Log("On tap action. \nURL: \(redirect.redirectUrl?.absoluteString ?? ""). \nPayload: \(redirect.payload)")
            .category(.inAppMessages).level(.debug).make()

        //        Mindbox.shared.executeAsyncOperation(operationSystemName: <#T##String#>, json: <#T##String#>)

        if redirect.redirectUrl != nil || !redirect.payload.isEmpty {
            onTap(redirect.redirectUrl, redirect.payload)
            close()
        }
    }

    private func onClose(inApp: InAppMessageUIModel, _ completion: @escaping () -> Void) {
        Log("InApp presentation completed")
            .category(.inAppMessages).level(.debug).make()
        inAppWindow?.isHidden = true
        inAppWindow?.rootViewController = nil
        completion()
    }

    private func makeInAppMessageWindow() -> UIWindow {
        let window: UIWindow
        if #available(iOS 13.0, *) {
            window = iOS13PlusWindow
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        self.inAppWindow = window
        window.windowLevel = UIWindow.Level.normal
        window.isHidden = false
        return window
    }

    @available(iOS 13.0, *)
    private var foregroundedScene: UIWindowScene? {
        for connectedScene in UIApplication.shared.connectedScenes {
            if let windowScene = connectedScene as? UIWindowScene, connectedScene.activationState == .foregroundActive {
                return windowScene
            }
        }
        return nil
    }

    @available(iOS 13.0, *)
    private var iOS13PlusWindow: UIWindow {
        if let foregroundedScene = foregroundedScene, foregroundedScene.delegate != nil {
            return UIWindow(windowScene: foregroundedScene)
        } else {
            return UIWindow(frame: UIScreen.main.bounds)
        }
    }
}
