import Foundation
import Bond
import MultipeerConnectivity

struct MultipeerMessage: Codable {
    let body: String
}

class MultipeerService: NSObject {

    static let sharedInstance = MultipeerService()

    private enum Constant {
        static let serviceType = "feather-epos"
        static let peerIdUserDefaultsKey = "com.feater.epos.peerid"
    }

    var logger: Logging? {
        didSet {
            for device in devices.array {
                device.logger = logger
            }
        }
    }

    let devices: MutableObservableArray<MultipeerDevice> = MutableObservableArray()

    // Cache the local PeerID object
    // Recreating the MCPeerId with a the same name produces a different object
    lazy var peerID: MCPeerID = {
        if
            let data = UserDefaults.standard.data(forKey: Constant.peerIdUserDefaultsKey),
            let peerID = try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data) {
            return peerID
        } else {
            let peerID = MCPeerID(displayName: UIDevice.current.name)
            let data = try? NSKeyedArchiver.archivedData(withRootObject: peerID, requiringSecureCoding: false)
            UserDefaults.standard.set(data, forKey: Constant.peerIdUserDefaultsKey)
            return peerID
        }
    }()

    private lazy var advertiser: MCNearbyServiceAdvertiser = {
        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Constant.serviceType)
        advertiser.delegate = self
        return advertiser
    }()

    private lazy var browser: MCNearbyServiceBrowser = {
        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Constant.serviceType)
        browser.delegate = self
        return browser
    }()

    func device(for peerID: MCPeerID) -> MultipeerDevice {
        guard let device = devices.array.first(where: { $0.peerID == peerID}) else {
            let device = MultipeerDevice(peerID: peerID)
            device.logger = logger
            device.delegate = self
            devices.append(device)
            return device
        }
        return device
    }

    func start() {
        logger?.log(message: "✅ START browsing & advertising")
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func restart() {
        logger?.log(message: "♻️ RESTART browsing & advertising")
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        disconnect()
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func disconnect() {
        logger?.log(message: "🔴 DID ENTER BACKGROUND")
        for device in self.devices.array {
            device.disconnect()
        }
    }

    func shouldInvitePeer(peerID: MCPeerID) -> Bool {
        return peerID.displayName > self.peerID.displayName
    }

}

// MARK: - Advertiser Delegate
extension MultipeerService: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        logger?.log(message: "➡️ INVITATION FROM \(peerID.displayName)")
        let device = MultipeerService.sharedInstance.device(for: peerID)
        device.connect()
        invitationHandler(true, device.session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger?.log(message: "did not start advertising: \(peerID.displayName) \(error.localizedDescription)")

    }

}

// MARK: - Browser Delegate
extension MultipeerService: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String : String]?) {
        logger?.log(message: "🔎😀 Found: \(peerID.displayName)")
        let currentDevice = device(for: peerID)
        currentDevice.isVisible.send(true)

        if shouldInvitePeer(peerID: peerID),
            currentDevice.state.value == .notConnected {
            logger?.log(message: "⬅️ INVITE \(peerID.displayName)")
            currentDevice.invite(browser: self.browser)
        } else {
            logger?.log(message: "Don't invite: \(peerID.displayName)")
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logger?.log(message: "🔎🥺 Lost: \(peerID.displayName)")
        device(for: peerID).isVisible.send(false)
        device(for: peerID).disconnect()
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logger?.log(message: "❗️did not start browsing for peers: \(peerID.displayName)")
    }

}

extension MultipeerService {

    var connectedDevices : [MultipeerDevice] {
        return devices.array.filter{ $0.state.value == .connected }
    }

    func send(message: String){
        logger?.log(message: "💌 SEND: \(message)")
        for device in devices.array {
            do {
                try device.send(text: message)
            } catch {
                logger?.log(message: error.localizedDescription)
            }
        }
    }
}

extension MultipeerService: MultipeerDeviceDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        if state == .notConnected {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // If the .notConnected peer is not visible anymore, id doesn't make sense to resend the invitation
                // If the lost peer is found again, it will automatically send the invitation
                let currentDevice = self.device(for: peerID)
                guard currentDevice.isVisible.value == true else {
                    self.logger?.log(message: "👁 NOT VISIBLE \(peerID.displayName)")
                    return
                }

                if self.shouldInvitePeer(peerID: peerID) {
                    self.logger?.log(message: "♻️ REINVITE: \(peerID.displayName)")
                    currentDevice.invite(browser: self.browser)
                }
            }
        }
    }

}

