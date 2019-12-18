import UIKit
import SnapKit
import Bond
import MultipeerConnectivity

extension DateFormatter {
    static var defaultDateFormatter: ISO8601DateFormatter = {
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter
    }()
}

class ViewController: UIViewController {

    // MARK: - UI
    private lazy var textView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.font = UIFont.preferredFont(forTextStyle: .body, compatibleWith: nil)
        textView.backgroundColor = UIColor.green.withAlphaComponent(0.1)
        return textView
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView()
        tableView.allowsSelection = false
        tableView.rowHeight = UITableView.automaticDimension
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        MultipeerService.sharedInstance.logger = self
        configureView()
    }

    private func configureView() {
        title = UIDevice.current.name
        view.addSubview(tableView)
        view.addSubview(textView)

        tableView.register(PeerCell.self, forCellReuseIdentifier: PeerCell.identifier)


        tableView.snp.makeConstraints { (make) in
            make.left.right.top.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(200)
        }
        textView.snp.makeConstraints({ (make) in
            make.left.right.bottom.equalToSuperview()
            make.top.equalTo(tableView.snp.bottom)
        })

        MultipeerService.sharedInstance.devices.bind(to: tableView) { (devices, indexPath, tableView) -> UITableViewCell in
            let cell = tableView.dequeueReusableCell(withIdentifier: PeerCell.identifier, for: indexPath) as! PeerCell
            cell.device.send(devices[indexPath.row])
            return cell
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(pingButtonPressed))
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(restartButtonPressed))

    }

    @objc func pingButtonPressed() {
        let message = "\(title!): \(DateFormatter.defaultDateFormatter.string(from: Date()))"
        MultipeerService.sharedInstance.send(message: message)
    }

    @objc func restartButtonPressed() {
        MultipeerService.sharedInstance.restart()
    }
}

extension ViewController: Logging {
    func log(message: String) {
        DispatchQueue.main.async {
            let formattedText = "\(DateFormatter.defaultDateFormatter.string(from: Date()))\n\(message)\n\n"
            print(formattedText)
            if let position = self.textView.textRange(from: self.textView.beginningOfDocument,
                                                      to: self.textView.beginningOfDocument) {
                self.textView.replace(position, withText: formattedText)
            }
        }
    }
}

