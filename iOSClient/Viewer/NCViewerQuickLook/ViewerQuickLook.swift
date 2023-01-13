//
//  ViewerQuickLook.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/01/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import QuickLook
import Mantis

struct ViewerQuickLook: UIViewControllerRepresentable {

    let url: URL

    @Binding var isPresentedQuickLook: Bool
    @Binding var previewStore: PreviewStore
    @Binding var timer: DispatchSourceTimer

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()

        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        context.coordinator.viewController = controller

        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: context.coordinator,
            action: #selector(context.coordinator.dismiss)
        )

        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("_crop_", comment: ""), style: UIBarButtonItem.Style.plain, target: context.coordinator,
            action: #selector(context.coordinator.crop)
        )

        /*
        timer.schedule(deadline: .now(), repeating: 0.3)
        timer.setEventHandler {
            let numItemsRight = controller.navigationItem.rightBarButtonItems?.count ?? 0
            if let buttonCrop = controller.navigationItem.leftBarButtonItems?.first {
                if numItemsRight > 1 && buttonCrop.isEnabled {
                    buttonCrop.isEnabled = false
                    if let buttonDone = controller.navigationItem.rightBarButtonItems?.last {
                        buttonDone.isEnabled = false
                    }
                }
                if numItemsRight == 1 && !buttonCrop.isEnabled {
                    buttonCrop.isEnabled = true
                    if let buttonDone = controller.navigationItem.rightBarButtonItems?.first {
                        buttonDone.isEnabled = true
                    }
                }
            }
        }
        timer.resume()
        */

        let navigationController = UINavigationController(rootViewController: controller)
        return navigationController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate, CropViewControllerDelegate {

        weak var viewController: QLPreviewController?
        let parent: ViewerQuickLook

        var image: UIImage?
        var hasChange = false

        init(parent: ViewerQuickLook) {
            self.parent = parent
        }

        @objc func dismiss() {
            self.viewController?.dismiss(animated: true)

            /*
            parent.isPresentedQuickLook = false
            if let image = image {
                parent.previewStore.image = image
            }
            parent.previewStore.hasChanges = hasChange
            */
        }

        // MARK: -

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
            return .createCopy
        }

        func previewController(_ controller: QLPreviewController, didSaveEditedCopyOf previewItem: QLPreviewItem, at modifiedContentsURL: URL) {
            guard NCUtilityFileSystem.shared.moveFile(atPath: modifiedContentsURL.path, toPath: parent.url.path) else { return }
            if let image = UIImage(contentsOfFile: parent.url.path) {
                self.image = image
                self.hasChange = true
            }
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as NSURL
        }

        // MARK: -

        func cropViewControllerDidCrop(_ cropViewController: Mantis.CropViewController, cropped: UIImage, transformation: Mantis.Transformation, cropInfo: Mantis.CropInfo) {
            cropViewController.dismiss(animated: true)
            guard let data = cropped.jpegData(compressionQuality: 1) else { return }
            do {
                try data.write(to: parent.url)
                self.image = cropped
                self.hasChange = true
                viewController?.reloadData()
            } catch {  }
        }
        func cropViewControllerDidCancel(_ cropViewController: Mantis.CropViewController, original: UIImage) {
            cropViewController.dismiss(animated: true)
        }

        func cropViewControllerDidFailToCrop(_ cropViewController: Mantis.CropViewController, original: UIImage) {}
        func cropViewControllerDidBeginResize(_ cropViewController: Mantis.CropViewController) {}
        func cropViewControllerDidEndResize(_ cropViewController: Mantis.CropViewController, original: UIImage, cropInfo: Mantis.CropInfo) {}
        func cropViewControllerDidImageTransformed(_ cropViewController: Mantis.CropViewController) { }

        @objc func crop() {

            guard let image = UIImage(contentsOfFile: parent.url.path) else { return }
            let config = Mantis.Config()

            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                config.localizationConfig.bundle = Bundle(identifier: bundleIdentifier)
                config.localizationConfig.tableName = "Localizable"
            }
            let cropViewController = Mantis.cropViewController(image: image, config: config)

            cropViewController.delegate = self
            cropViewController.modalPresentationStyle = .fullScreen

            viewController?.present(cropViewController, animated: true)
        }
    }
}
