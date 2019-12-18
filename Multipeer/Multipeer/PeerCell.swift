import Foundation
import UIKit
import Bond
import ReactiveKit
import SnapKit

class PeerCell: UITableViewCell {

    static let identifier = "Multipeer.PeerCell.Identifier"

    let device: Observable<MultipeerDevice?> = Observable(nil)

    private var statusDisposable: Disposable?

    private lazy var peerNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        return label
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .body)
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureCell()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureCell()
    }

    private func configureCell() {
        contentView.addSubview(peerNameLabel)
        contentView.addSubview(statusLabel)

        peerNameLabel.snp.makeConstraints { (make) in
            make.left.right.top.equalToSuperview().offset(10)
            make.height.equalTo(20)
        }

        statusLabel.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
            make.top.equalTo(peerNameLabel.snp.bottom)
            make.height.equalTo(20)
        }

        bag.add(disposable: device.observeNext { [weak self] (device) in
            guard let self = self else { return }
            guard let device = device else {
                self.peerNameLabel.text = nil
                self.statusLabel.text = nil
                return
            }
            self.peerNameLabel.text = device.name

            self.statusDisposable?.dispose()

            self.statusDisposable = device.state.receive(on:
                DispatchQueue.main)
                .observeNext(with: { [weak self] (status) in
                self?.statusLabel.text = "\(status)"
                switch status {
                case .notConnected:
                    self?.peerNameLabel.textColor = .red
                case .connecting:
                    self?.peerNameLabel.textColor = .blue
                case .connected:
                    self?.peerNameLabel.textColor = .green
                default:
                    self?.peerNameLabel.textColor = .black
                }
            })
        })
    }

}
