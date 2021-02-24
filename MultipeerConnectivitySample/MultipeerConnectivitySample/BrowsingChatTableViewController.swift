//
//  BrowsingChatTableViewController.swift
//  MultipeerConnectivitySample
//
//  Created by makoto on 2021/02/19.
//

import UIKit
import MultipeerConnectivity

final class BrowsingChatTableViewController: UITableViewController {

    private var messages = [String]()

    private let serviceType = "browsing-chat"
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var sendButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        sendButton = .init(title: "送信", style: .done, target: self, action: #selector(sendMessage(_:)))
        sendButton.isEnabled = false
        let browseButton = UIBarButtonItem(title: "検索", style: .done, target: self, action: #selector(browse(_:)))
        navigationItem.rightBarButtonItems = [browseButton, sendButton]

        let peerID = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: peerID)
        session.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // たまに切れない時があるのでここで切断
        if presentedViewController == nil {
            advertiser.stopAdvertisingPeer()
            session.disconnect()
        }
    }

    @objc private func sendMessage(_ sender: Any) {
        let message = "\(session.myPeerID.displayName)からのメッセージ"
        do {
            try session.send(message.data(using: .utf8)!, toPeers: session.connectedPeers, with: .reliable)
            addMessage(message)
        } catch let error {
            print(error.localizedDescription)
        }
    }

    @objc private func browse(_ sender: Any) {
        let vc = MCBrowserViewController(serviceType: serviceType, session: session)
        vc.delegate = self
        present(vc, animated: true)
    }

    private func addMessage(_ message: String) {
        messages.append(message)
        tableView.beginUpdates()
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.insertRows(at: [indexPath], with: .automatic)
        tableView.endUpdates()
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
}

extension BrowsingChatTableViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = messages[indexPath.row]
        return cell
    }
}

extension BrowsingChatTableViewController: MCSessionDelegate {

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
            self.addMessage(message)
            self.sendButton.isEnabled = !self.session.connectedPeers.isEmpty
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = String(data: data, encoding: .utf8) else {
            return
        }
        DispatchQueue.main.async {
            self.addMessage(message)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        assertionFailure("非対応")
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        assertionFailure("非対応")
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        assertionFailure("非対応")
    }
}

extension BrowsingChatTableViewController: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print(error.localizedDescription)
    }
}

extension BrowsingChatTableViewController: MCBrowserViewControllerDelegate {

    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true)
    }

    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true)
    }

    func browserViewController(_ browserViewController: MCBrowserViewController, shouldPresentNearbyPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) -> Bool {
        return true
    }
}
