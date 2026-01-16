Screen의 예시 코드입니다. 주석을 통해 각 요소를 설명합니다.

```swift
import CoreFlow
import UIKit

public final class LoginScreen: Screen<LoginCore> {
    private let loginButton = CoreButton {
        TestView(string: "로그인 실행", size: .init(width: 100, height: 50))
    }
    private let loadingIndicator = UIActivityIndicatorView()
    
    // 상태 관찰 또는 액션 전송 관련 코드를 구현합니다.
    // 액션 전송의 경우 UI에 따라 bind 함수 외부에서 진행할 수 있습니다.
    public override func bind() {
        observeDistinctState(\.isLoading) { [weak self] output in
            guard let self else { return }
            
            loadingIndicator.isHidden = !output
            if output {
                loadingIndicator.startAnimating()
            } else {
                loadingIndicator.stopAnimating()
            }
            
            loginButton.isUserInteractionEnabled = !output
        }
        
        bind(
            onEmit: loginButton.onTap,
            send: .loginButtonTapped
        )
    }
}

// 화면 라이프 사이클 관련 함수 집합입니다.
extension LoginScreen {
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        reactor.send(.viewDidLoad)
    }
}

extension LoginScreen {
    // 모든 UI 설정(속성, 레이아웃) 메서드 호출을 취합합니다.
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        setupLoginButton()
        setupLoadingIndicator()
    }
    
    private func setupLoginButton() {
        view.addSubview(loginButton)
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator.isHidden = true
        
        view.addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
```