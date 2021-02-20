//
//  SendImageViewController.swift
//  MultipeerConnectivitySample
//
//  Created by makoto on 2021/02/19.
//

import UIKit
import MultipeerConnectivity

final class SendImageViewController: UIViewController {

    private let serviceType = "send-image"
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    private var images = [String]()

    @IBOutlet private weak var stateLabel: UILabel!
    @IBOutlet private weak var collectionView: UICollectionView! {
        didSet {
            collectionView.delegate = self
            collectionView.dataSource = self
            collectionView.dragDelegate = self
            collectionView.dragInteractionEnabled = true
        }
    }
    @IBOutlet private weak var dropAreaView: UIView! {
        didSet {
            dropAreaView.addInteraction(UIDropInteraction(delegate: self))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        images = contentsOfImagesDirectory()
        if images.isEmpty {
            createColorImages()
            images = contentsOfImagesDirectory()
        }
        navigationItem.rightBarButtonItem = .init(title: "リセット", style: .done, target: self, action: #selector(resetImages(_:)))

        let peerID = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: peerID)
        session.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()

        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()

        updateState()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // たまに切れない時があるのでここで切断
        browser.stopBrowsingForPeers()
        advertiser.stopAdvertisingPeer()
        session.disconnect()
    }

    @objc private func resetImages(_ sender: Any) {
        createColorImages()
        images = contentsOfImagesDirectory()
        collectionView.reloadData()
    }

    private func sendImage(seq: Int) {
        let url = getImageURL(seq: seq)
        session.connectedPeers.forEach { peer in
            session.sendResource(at: url, withName: "\(seq).png", toPeer: peer) { (error) in
                if let error = error {
                    print(error.localizedDescription)
                }
            }
        }
    }

    private func updateState() {
        let isConnected = !session.connectedPeers.isEmpty
        stateLabel.text = isConnected ? "接続中" : "未接続"
        dropAreaView.isUserInteractionEnabled = isConnected
        dropAreaView.alpha = isConnected ? 1.0 : 0.3
    }
}

extension SendImageViewController: UIDropInteractionDelegate {
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.items.filter { $0.itemProvider.canLoadObject(ofClass: NSString.self) }.forEach { item in
            item.itemProvider.loadObject(ofClass: NSString.self) { [weak self] (object, error) in
                if let string = object as? NSString {
                    self?.sendImage(seq: string.integerValue)
                }
            }
        }
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }

    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return true
    }
}

extension SendImageViewController: UICollectionViewDelegate {
}

extension SendImageViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let text = "\(indexPath.row)" as NSString
        return [UIDragItem(itemProvider: NSItemProvider(object: text))]
    }
}

extension SendImageViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
        let imageView = cell.viewWithTag(1) as? UIImageView
        imageView?.image = getImage(seq: indexPath.row)
        return cell
    }
}

extension SendImageViewController: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let message: String
        switch state {
        case .connected:
            message = "\(peerID.displayName)が接続されました"
        case .connecting:
            message = "\(peerID.displayName)が接続中です"
        case .notConnected:
            message = "\(peerID.displayName)が切断されました"
        @unknown default:
            message = "\(peerID.displayName)が想定外の状態です"
        }
        DispatchQueue.main.async {
            print(message)
            self.updateState()
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        assertionFailure("非対応")
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        assertionFailure("非対応")
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            return
        }
        guard let url = localURL else {
            return
        }
        copyImage(seq: images.count, url: url)
        images = contentsOfImagesDirectory()
        DispatchQueue.main.async {
            let indexPath = IndexPath(row: self.images.count - 1, section: 0)
            self.collectionView.insertItems(at: [indexPath])
            self.collectionView.scrollToItem(at: indexPath, at: .bottom, animated: true)
        }
    }
}

extension SendImageViewController: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

extension SendImageViewController: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        guard let session = session else {
            return
        }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 0)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    }
}

extension SendImageViewController {
    private var imagesDirectory: String {
        return NSHomeDirectory() + "/Documents/Images"
    }

    private func randomColor(alpha: CGFloat) -> UIColor {
        let r = CGFloat.random(in: 0...255) / 255.0
        let g = CGFloat.random(in: 0...255) / 255.0
        let b = CGFloat.random(in: 0...255) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: alpha)
    }

    private func createColorImages() {
        if FileManager.default.fileExists(atPath: imagesDirectory) {
            removeImageDirectory()
        }
        createImageDirectory()
        for i in 0...5 {
            let image = UIImage(color: randomColor(alpha: 1.0), size: .init(width: 100, height: 100))
            saveImage(image, seq: i)
        }
    }

    private func copyImage(seq: Int, url: URL) {
        do {
            try FileManager.default.copyItem(at: url, to: getImageURL(seq: seq))
        } catch let error {
            print(error.localizedDescription)
        }
    }

    private func getImageURL(seq: Int) -> URL {
        let path = imagesDirectory + "/\(seq).png"
        return URL(fileURLWithPath: path)
    }

    private func getImage(seq: Int) -> UIImage? {
        let path = imagesDirectory + "/\(seq).png"
        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }
        return UIImage(data: data)
    }

    private func createImageDirectory() {
        do {
            try FileManager.default.createDirectory(atPath: imagesDirectory, withIntermediateDirectories: false, attributes: nil)
        } catch let error {
            print(error.localizedDescription)
        }
    }

    private func removeImageDirectory() {
        do {
            try FileManager.default.removeItem(atPath: imagesDirectory)
        } catch let error {
            print(error.localizedDescription)
        }
    }

    private func saveImage(_ image: UIImage, seq: Int) {
        let path = imagesDirectory + "/\(seq).png"
        if !FileManager.default.createFile(atPath: path, contents: image.pngData(), attributes: nil) {
            print("Create file error")
        }
    }

    private func contentsOfImagesDirectory() -> [String] {
        do {
            return try FileManager.default.contentsOfDirectory(atPath: imagesDirectory)
        } catch let error {
            print(error.localizedDescription)
            return []
        }
    }
}

public extension UIImage {
    convenience init(color: UIColor, size: CGSize) {
        let image = UIGraphicsImageRenderer(size: size).image { context in
            context.cgContext.setFillColor(color.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }

        if let cgImage = image.cgImage {
            self.init(cgImage: cgImage)
        } else {
            self.init()
        }
    }
}
