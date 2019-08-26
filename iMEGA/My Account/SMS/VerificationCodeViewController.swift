
import UIKit

class VerificationCodeViewController: UIViewController {
    
    private let verificationCodeCount = 6
    private let resendCheckTimeInterval = 30.0
    private var verificationCodeFields = [UITextField]()
    
    @IBOutlet private var resendButton: UIButton!
    @IBOutlet private var confirmButton: UIButton!
    @IBOutlet private var didnotReceiveCodeLabel: UILabel!
    @IBOutlet private var verificationCodeSentToLabel: UILabel!
    @IBOutlet private var phoneNumberLabel: UILabel!
    @IBOutlet private var codeFieldsContainerView: UIStackView!
    @IBOutlet private var errorImageView: UIImageView!
    @IBOutlet private var errorMessageLabel: UILabel!
    @IBOutlet private var errorView: UIStackView!
    @IBOutlet private var resendStackView: UIStackView!
    
    var phoneNumber: PhoneNumber!
    
    private var verificationCode: String {
        return verificationCodeFields.compactMap { $0.text }.joined()
    }
    
    class func instantiate(with phoneNumber: PhoneNumber) -> VerificationCodeViewController {
        let controller = VerificationCodeViewController.instantiate(withStoryboardName: "SMSVerification")
        controller.phoneNumber = phoneNumber
        return controller
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Verify Your Account"
        
        resendButton.tintColor = UIColor.mnz_green00BFA5()
        didnotReceiveCodeLabel.textColor = UIColor.gray
        errorImageView.tintColor = UIColor.mnz_redError()
        errorMessageLabel.textColor = UIColor.mnz_redError()
        
        configCodeFieldsAppearance()
        configResendView()

        verificationCodeFields = codeFieldsContainerView.subviews.compactMap { $0 as? UITextField }
        verificationCodeFields.first?.becomeFirstResponder()
        
        phoneNumberLabel.text = PhoneNumberKit().format(phoneNumber, toType: .e164)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.isNavigationBarHidden = false
    }
    
    // MARK: - Config views
    
    private func configResendView() {
        resendStackView.isHidden = true
        DispatchQueue.main.asyncAfter(deadline: .now() + resendCheckTimeInterval) {
            guard self.verificationCode.count == 0 else { return }
            
            UIView.animate(withDuration: 0.75, animations: {
                self.resendStackView.isHidden = false
            })
        }
    }
    
    private func configCodeFieldsAppearance(with error: MEGAError? = nil) {
        if let error = error {
            resendStackView.isHidden = false
            errorView.isHidden = false
            verificationCodeFields.forEach {
                $0.layer.cornerRadius = 8
                $0.layer.borderWidth = 2
                $0.layer.borderColor = UIColor(red:1, green:0.2, blue:0.23, alpha:0.4).cgColor
                $0.layer.shadowOffset = CGSize(width: 0, height: 1)
                $0.layer.shadowColor = UIColor.mnz_black000000_01()?.cgColor
                $0.layer.shadowOpacity = 1
                $0.layer.shadowRadius = 0
            }
            
            var errorMessage: String?
            switch error.type {
            case .apiEAccess: // you have reached the verification limits.
                errorMessage = "You have reached your limit in getting verification code for today"
            case .apiEFailed: // the verification code does not match.
                errorMessage = "The verification code does not match"
            case .apiEExpired: // the phone number was verified on a different account.
                errorMessage = "Your account is already verified by an phone number"
            default: break
            }
            errorMessageLabel.text = errorMessage
            errorMessageLabel.textColor = UIColor.mnz_redError()
        } else {
            errorView.isHidden = true
            verificationCodeFields.forEach {
                $0.layer.cornerRadius = 8
                $0.layer.borderWidth = 1
                $0.layer.borderColor = UIColor.mnz_black000000_01()?.cgColor
                $0.layer.shadowOffset = CGSize(width: 0, height: 1)
                $0.layer.shadowColor = UIColor.mnz_black000000_01()?.cgColor
                $0.layer.shadowOpacity = 1
                $0.layer.shadowRadius = 0
            }
        }
    }
    
    // MARK: - UI Actions
    
    @IBAction private func didTapResendButton() {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction private func didTapConfirmButton() {
        let code = verificationCode
        guard code.count == verificationCodeCount else { return }
        
        SVProgressHUD.show()
        MEGASdkManager.sharedMEGASdk()?.checkSMSVerificationCode(code, delegate: MEGAGenericRequestDelegate() {
            [weak self] request, error in
            SVProgressHUD.dismiss()
            if error.type == .apiOk {
                self?.checkSMSVerificationCodeSucceeded()
            } else {
                self?.configCodeFieldsAppearance(with: error)
            }
        })
    }
    
    @IBAction private func didEditingChangeInTextField(_ textField: UITextField) {
        confirmButton.isEnabled = verificationCode.count == verificationCodeCount
    }
    
    private func checkSMSVerificationCodeSucceeded() {
        setEditing(false, animated: true)
        configCodeFieldsAppearance(with: nil)
        dismiss(animated: true, completion: nil)
        
        if let session = SAMKeychain.password(forService: MEGAPasswordService, account: MEGAPasswordName)  {
            MEGASdkManager.sharedMEGASdk()?.fastLogin(withSession: session, delegate: MEGALoginRequestDelegate())
        } else {
            (UIApplication.shared.delegate as? AppDelegate)?.showOnboarding()
        }
    }
}

// MARK: - UITextFieldDelegate

extension VerificationCodeViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard string.mnz_isDecimalNumber else {
            return false
        }
        
        if string.count >= verificationCodeCount {
            distributeCodeString(string)
            didEditingChangeInTextField(textField)
            return false
        }
        
        if string.count > 0 {
            textField.text = String(string[string.startIndex])
            makeNextCodeFieldBecomeFirstResponder(for: textField)
            didEditingChangeInTextField(textField)
            return false
        }
        
        return  true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didTapResendButton()
        return false
    }
    
    private func distributeCodeString(_ string: String) {
        for (code, field) in zip(string, verificationCodeFields) {
            field.text = String(code)
        }
    }
    
    private func makeNextCodeFieldBecomeFirstResponder(for textField: UITextField) {
        guard let currentIndex = verificationCodeFields.firstIndex(of: textField), currentIndex < verificationCodeFields.count - 1 else { return }
        verificationCodeFields[currentIndex + 1].becomeFirstResponder()
    }
    
    private func makePreviousCodeFieldBecomeFirstResponder(for textField: UITextField) {
        guard let currentIndex = verificationCodeFields.firstIndex(of: textField), currentIndex > 0 else { return }
        verificationCodeFields[currentIndex - 1].becomeFirstResponder()
    }
}

// MARK: - SingleCodeTextFieldDelegate

extension VerificationCodeViewController: SingleCodeTextFieldDelegate {
    func didDeleteBackwardInTextField(_ textField: SingleCodeTextField) {
        guard textField.text?.count ?? 0 == 0 else { return }
        makePreviousCodeFieldBecomeFirstResponder(for: textField)
    }
}
