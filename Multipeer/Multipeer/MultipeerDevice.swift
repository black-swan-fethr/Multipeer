import Foundation
import MultipeerConnectivity
import Bond

protocol MultipeerDeviceDelegate: class {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState)
}

class MultipeerDevice: NSObject {

    let peerID: MCPeerID

    var session: MCSession?

    var name: String
    var state = Observable(MCSessionState.notConnected)
    var isVisible = Observable(false)
    var logger: Logging?

    weak var delegate: MultipeerDeviceDelegate?

    init(peerID: MCPeerID) {
        self.name = peerID.displayName
        self.peerID = peerID
        super.init()
    }

    func connect() {
        guard session == nil else { return }
        session = MCSession(peer: MultipeerService.sharedInstance.peerID,
                            securityIdentity: nil,
                            encryptionPreference: .required)
        session?.delegate = self
    }

    func disconnect() {
        logger?.log(message: "☠️ DISCONNECT: \(peerID.displayName)")
        state.send(.notConnected)
        session?.disconnect()
        session?.delegate = nil
        session = nil
    }

    func invite(browser: MCNearbyServiceBrowser) {
        connect()
        browser.invitePeer(peerID, to: session!, withContext: nil, timeout: 3.0)
    }
}

extension MultipeerDevice: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        logger?.log(message: "\(state) \(peerID.displayName)")
        self.state.send(state)
        delegate?.session(session, peer: peerID, didChange: state)
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {

        if let message = try? JSONDecoder().decode(MultipeerMessage.self, from: data) {
            logger?.log(message: "💌 RECEIVED: \(message)")
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        logger?.log(message: "didReceive stream")
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        logger?.log(message: "didReceive resource")
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        logger?.log(message: "did finish receiving resource")

    }

    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        logger?.log(message: "📝 Did receive certificate")
        certificateHandler(true)
    }

}

extension MultipeerDevice {
    func send(text: String) throws {
        let message = MultipeerMessage(body: text)
        let payload = try JSONEncoder().encode(message)
        try session?.send(payload, toPeers: [peerID], with: .reliable)
    }
}

extension MCSessionState: CustomDebugStringConvertible {

    public var debugDescription: String {
        switch self {
        case .connected:
            return "✅ Connected"
        case .connecting:
            return "⏳ Connecting"
        case .notConnected:
            return "🔴 Not connected"
        @unknown default:
            return "💩"
        }
    }

}
