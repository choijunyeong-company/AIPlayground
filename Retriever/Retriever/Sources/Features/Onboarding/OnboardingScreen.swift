//
//  OnboardingScreen.swift
//  Retriever
//

import CoreFlow
import UIKit

public final class OnboardingScreen: Screen<OnboardingCore> {
    public override func bind() {
        // Bindings between UI and Reactor go here.
    }
}

extension OnboardingScreen {
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        reactor.send(.viewDidLoad)
    }
}

extension OnboardingScreen {
    private func setupUI() {
        view.backgroundColor = .systemBackground
    }
}
