import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import KWGramCore

/// One tappable colour swatch in the palette grid.
private final class KWGramColorSwatchButton: UIControl {
    let colorIndex: Int32
    private let swatch = UIView()
    private let ring = UIView()
    private let check = UIImageView()

    init(colorIndex: Int32, color: UIColor) {
        self.colorIndex = colorIndex
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.isAccessibilityElement = true
        self.accessibilityLabel = "Цвет \(colorIndex + 1)"

        self.ring.translatesAutoresizingMaskIntoConstraints = false
        self.ring.layer.cornerRadius = 26.0
        self.ring.layer.borderWidth = 3.0
        self.ring.layer.borderColor = UIColor.clear.cgColor
        self.ring.isUserInteractionEnabled = false
        self.addSubview(self.ring)

        self.swatch.translatesAutoresizingMaskIntoConstraints = false
        self.swatch.backgroundColor = color
        self.swatch.layer.cornerRadius = 21.0
        self.swatch.isUserInteractionEnabled = false
        self.addSubview(self.swatch)

        self.check.translatesAutoresizingMaskIntoConstraints = false
        self.check.image = UIImage(systemName: "checkmark")?.withTintColor(.white, renderingMode: .alwaysOriginal)
        self.check.contentMode = .scaleAspectFit
        self.check.isHidden = true
        self.check.isUserInteractionEnabled = false
        self.addSubview(self.check)

        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalToConstant: 52.0),
            self.heightAnchor.constraint(equalToConstant: 52.0),
            self.ring.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.ring.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.ring.topAnchor.constraint(equalTo: self.topAnchor),
            self.ring.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.swatch.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 5.0),
            self.swatch.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -5.0),
            self.swatch.topAnchor.constraint(equalTo: self.topAnchor, constant: 5.0),
            self.swatch.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -5.0),
            self.check.centerXAnchor.constraint(equalTo: self.swatch.centerXAnchor),
            self.check.centerYAnchor.constraint(equalTo: self.swatch.centerYAnchor),
            self.check.widthAnchor.constraint(equalToConstant: 18.0),
            self.check.heightAnchor.constraint(equalToConstant: 18.0)
        ])
        self.updateAppearance(selected: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateAppearance(selected: Bool) {
        self.ring.layer.borderColor = (selected ? UIColor.white : UIColor.clear).cgColor
        self.check.isHidden = !selected
        self.swatch.alpha = selected ? 1.0 : 0.85
    }
}

/// Full-screen "liquid glass" colour picker for the user's own name colour and profile colour.
/// Stores the choice via `KWGramPersonalColorStore` and applies it to the real account through
/// the injected `applyColor` closure (reached by the runtime, which lives behind AccountContext).
private final class KWGramPersonalColorPickerController: ViewController {
    private let context: AccountContext
    private let presentationData: PresentationData
    private let stateDisposable = MetaDisposable()

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    private var headerTopConstraint: NSLayoutConstraint?

    private let nameGridStack = UIStackView()
    private let profileGridStack = UIStackView()
    private var nameButtons: [KWGramColorSwatchButton] = []
    private var profileButtons: [KWGramColorSwatchButton] = []
    private let nameLabel = UILabel()
    private let profileLabel = UILabel()

    private var primaryColor: UIColor = .label
    private var secondaryColor: UIColor = .secondaryLabel

    private var selectedNameIndex: Int32?
    private var selectedProfileIndex: Int32?
    private var didLoadInitialState = false

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: nil)
        self.displayNavigationBar = false
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.stateDisposable.dispose()
    }

    override func loadDisplayNode() {
        let node = ASDisplayNode()
        node.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.displayNode = node
        self.displayNodeDidLoad()
        self.configureView(node.view)

        self.stateDisposable.set((KWGramPersonalColorStore.signal(postbox: self.context.account.postbox)
        |> take(1)
        |> deliverOnMainQueue).startStrict(next: { [weak self] colors in
            self?.applyInitialState(colors)
        }))
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.headerTopConstraint?.constant = layout.insets(options: [.statusBar]).top
        let bottomInset = layout.intrinsicInsets.bottom
        self.scrollView.contentInset.bottom = bottomInset + 24.0
        self.scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    private func configureView(_ rootView: UIView) {
        let theme = self.presentationData.theme
        self.primaryColor = theme.list.itemPrimaryTextColor
        self.secondaryColor = theme.list.itemSecondaryTextColor
        rootView.backgroundColor = theme.list.blocksBackgroundColor
        rootView.disablesInteractiveTransitionGestureRecognizer = true

        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(header)
        let headerTop = header.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 44.0)
        self.headerTopConstraint = headerTop
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            headerTop,
            header.heightAnchor.constraint(equalToConstant: 44.0)
        ])

        let backButton = self.makeGlyphButton(systemName: "chevron.left", action: #selector(self.closePressed))
        header.addSubview(backButton)
        let doneButton = self.makeGlyphButton(systemName: "checkmark", action: #selector(self.savePressed))
        header.addSubview(doneButton)
        let titleLabel = self.makeLabel("Персональные цвета", font: .systemFont(ofSize: 17.0, weight: .semibold), color: self.primaryColor)
        titleLabel.textAlignment = .center
        header.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 12.0),
            backButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 34.0),
            backButton.heightAnchor.constraint(equalToConstant: 34.0),
            doneButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -12.0),
            doneButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            doneButton.widthAnchor.constraint(equalToConstant: 34.0),
            doneButton.heightAnchor.constraint(equalToConstant: 34.0),
            titleLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])

        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.showsVerticalScrollIndicator = false
        rootView.addSubview(self.scrollView)
        NSLayoutConstraint.activate([
            self.scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            self.scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6.0),
            self.scrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])

        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.addSubview(self.contentView)
        NSLayoutConstraint.activate([
            self.contentView.leadingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.leadingAnchor),
            self.contentView.trailingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.trailingAnchor),
            self.contentView.topAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.topAnchor),
            self.contentView.bottomAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.bottomAnchor),
            self.contentView.widthAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.widthAnchor)
        ])

        self.stackView.translatesAutoresizingMaskIntoConstraints = false
        self.stackView.axis = .vertical
        self.stackView.alignment = .fill
        self.stackView.spacing = 14.0
        self.contentView.addSubview(self.stackView)
        NSLayoutConstraint.activate([
            self.stackView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 16.0),
            self.stackView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -16.0),
            self.stackView.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 12.0),
            self.stackView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -24.0)
        ])

        self.stackView.addArrangedSubview(self.makeInfoPanel())
        self.stackView.addArrangedSubview(self.makeNamePanel())
        self.stackView.addArrangedSubview(self.makeProfilePanel())

        self.updateUI()
    }

    /// The palette: Telegram's own name colours, read live from `context.peerNameColors`.
    private func paletteColors() -> [Int32] {
        return self.context.peerNameColors.displayOrder
    }

    private func uiColor(forIndex index: Int32) -> UIColor {
        let colors = self.context.peerNameColors
        return colors.get(PeerNameColor(rawValue: index), dark: self.presentationData.theme.overallDarkAppearance).main
    }

    private func makeInfoPanel() -> UIView {
        let panel = KWGramGlass.makePanel(cornerRadius: 20.0)
        let label = self.makeLabel("Выбери цвет имени и цвет фона профиля из палитры Telegram. KW Gram применит их к вашему аккаунту и вернёт при сбое.", font: .systemFont(ofSize: 13.0, weight: .regular), color: self.secondaryColor)
        label.numberOfLines = 0
        panel.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            label.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            label.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14.0),
            label.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14.0)
        ])
        return panel
    }

    private func makeNamePanel() -> UIView {
        let panel = KWGramGlass.makePanel(cornerRadius: 20.0)
        self.nameLabel.translatesAutoresizingMaskIntoConstraints = false
        self.nameLabel.font = .systemFont(ofSize: 17.0, weight: .semibold)
        self.nameLabel.textColor = self.primaryColor
        panel.addSubview(self.nameLabel)
        self.nameGridStack.translatesAutoresizingMaskIntoConstraints = false
        self.nameGridStack.axis = .vertical
        self.nameGridStack.alignment = .leading
        self.nameGridStack.spacing = 10.0
        panel.addSubview(self.nameGridStack)
        NSLayoutConstraint.activate([
            self.nameLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            self.nameLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16.0),
            self.nameGridStack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16.0),
            self.nameGridStack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16.0),
            self.nameGridStack.topAnchor.constraint(equalTo: self.nameLabel.bottomAnchor, constant: 12.0),
            self.nameGridStack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16.0)
        ])
        self.populateGrid(stack: self.nameGridStack, buttons: &self.nameButtons, action: #selector(self.namePressed(_:)))
        return panel
    }

    private func makeProfilePanel() -> UIView {
        let panel = KWGramGlass.makePanel(cornerRadius: 20.0)
        self.profileLabel.translatesAutoresizingMaskIntoConstraints = false
        self.profileLabel.font = .systemFont(ofSize: 17.0, weight: .semibold)
        self.profileLabel.textColor = self.primaryColor
        panel.addSubview(self.profileLabel)
        self.profileGridStack.translatesAutoresizingMaskIntoConstraints = false
        self.profileGridStack.axis = .vertical
        self.profileGridStack.alignment = .leading
        self.profileGridStack.spacing = 10.0
        panel.addSubview(self.profileGridStack)
        NSLayoutConstraint.activate([
            self.profileLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            self.profileLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16.0),
            self.profileGridStack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16.0),
            self.profileGridStack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16.0),
            self.profileGridStack.topAnchor.constraint(equalTo: self.profileLabel.bottomAnchor, constant: 12.0),
            self.profileGridStack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16.0)
        ])
        self.populateGrid(stack: self.profileGridStack, buttons: &self.profileButtons, action: #selector(self.profilePressed(_:)))
        return panel
    }

    /// Fills a vertical grid with a "Сбросить" row plus swatch rows (4 per row).
    private func populateGrid(stack: UIStackView, buttons: inout [KWGramColorSwatchButton], action: Selector) {
        let resetButton = UIButton(type: .system)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.setTitle("Сбросить цвет", for: .normal)
        resetButton.titleLabel?.font = .systemFont(ofSize: 15.0, weight: .regular)
        resetButton.contentHorizontalAlignment = .leading
        resetButton.addTarget(self, action: action, for: .touchUpInside)
        resetButton.tag = -1
        stack.addArrangedSubview(resetButton)
        NSLayoutConstraint.activate([
            resetButton.heightAnchor.constraint(equalToConstant: 30.0),
            resetButton.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 2.0)
        ])

        let indices = self.paletteColors()
        var rowStack: UIStackView?
        for (i, index) in indices.enumerated() {
            if i % 4 == 0 {
                rowStack = UIStackView()
                rowStack!.axis = .horizontal
                rowStack!.alignment = .center
                rowStack!.spacing = 10.0
                rowStack!.distribution = .fill
                stack.addArrangedSubview(rowStack!)
                NSLayoutConstraint.activate([
                    rowStack!.heightAnchor.constraint(equalToConstant: 52.0),
                    rowStack!.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 2.0)
                ])
            }
            let button = KWGramColorSwatchButton(colorIndex: index, color: self.uiColor(forIndex: index))
            button.addTarget(self, action: action, for: .touchUpInside)
            buttons.append(button)
            rowStack?.addArrangedSubview(button)
        }
    }

    private func makeGlyphButton(systemName: String, action: Selector) -> UIView {
        let panel = KWGramGlass.makeCircleButton(diameter: 34.0)
        panel.translatesAutoresizingMaskIntoConstraints = false
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = self.primaryColor
        button.setImage(UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15.0, weight: .semibold)), for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        panel.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            button.topAnchor.constraint(equalTo: panel.topAnchor),
            button.bottomAnchor.constraint(equalTo: panel.bottomAnchor)
        ])
        return panel
    }

    private func makeLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = font
        label.textColor = color
        return label
    }

    private func applyInitialState(_ colors: KWGramPersonalColors) {
        guard !self.didLoadInitialState else {
            return
        }
        self.didLoadInitialState = true
        self.selectedNameIndex = colors.nameColorIndex
        self.selectedProfileIndex = colors.profileColorIndex
        self.updateUI()
    }

    private func popSelf() {
        if let navigationController = self.navigationController as? NavigationController {
            let _ = navigationController.popViewController(animated: true)
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    @objc private func closePressed() {
        self.popSelf()
    }

    @objc private func namePressed(_ sender: UIControl) {
        self.selectedNameIndex = (sender as? KWGramColorSwatchButton)?.colorIndex
        self.updateUI()
    }

    @objc private func profilePressed(_ sender: UIControl) {
        self.selectedProfileIndex = (sender as? KWGramColorSwatchButton)?.colorIndex
        self.updateUI()
    }

    @objc private func savePressed() {
        let nameIndex = self.selectedNameIndex
        let profileIndex = self.selectedProfileIndex
        let _ = self.context.account.postbox.transaction { transaction -> Void in
            KWGramPersonalColorStore.write(transaction: transaction, colors: KWGramPersonalColors(nameColorIndex: nameIndex, profileColorIndex: profileIndex))
        }.start()
        // Push the new colours onto the real account immediately.
        if nameIndex != nil || profileIndex != nil {
            let engine = self.context.engine
            let nameColor: UpdateNameColor = nameIndex.map { .preset(color: PeerNameColor(rawValue: $0), backgroundEmojiId: nil) } ?? .preset(color: .blue, backgroundEmojiId: nil)
            let profileColor: PeerNameColor? = profileIndex.map { PeerNameColor(rawValue: $0) }
            let _ = (engine.accountData.updateNameColorAndEmoji(nameColor: nameColor, profileColor: profileColor, profileBackgroundEmojiId: nil)
            |> deliverOnMainQueue).start()
        }
        self.popSelf()
    }

    private func updateUI() {
        self.nameLabel.text = "Цвет имени"
        self.profileLabel.text = "Цвет фона профиля"
        for button in self.nameButtons {
            button.updateAppearance(selected: button.colorIndex == self.selectedNameIndex)
        }
        for button in self.profileButtons {
            button.updateAppearance(selected: button.colorIndex == self.selectedProfileIndex)
        }
    }
}

func kwGramPersonalColorPickerController(context: AccountContext) -> ViewController {
    return KWGramPersonalColorPickerController(context: context)
}
