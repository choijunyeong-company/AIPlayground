//___FILEHEADER___

import CoreFlow
import UIKit

public final class ___VARIABLE_productName___Screen: Screen<___VARIABLE_productName___Core> {
    public override func bind() {
        // Bindings between UI and Reactor go here.
    }
}

extension ___VARIABLE_productName___Screen {
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()   
        reactor.send(.viewDidLoad)
    }
}

extension ___VARIABLE_productName___Screen {
    private func setupUI() {
        view.backgroundColor = .systemBackground
    }
}
