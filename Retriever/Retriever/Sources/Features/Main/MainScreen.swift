import CoreFlow
import UIKit

public final class MainScreen: Screen<MainCore> {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "메인화면"
        label.font = .systemFont(ofSize: 48, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    public override func bind() {}
}

extension MainScreen {
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        reactor.send(.viewDidLoad)
    }
}

extension MainScreen {
    private func setupUI() {
        view.backgroundColor = .systemBackground
        setupTitleLabel()
    }

    private func setupTitleLabel() {
        view.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
