//
//  Copyright (c) 2020 Touch Instinct
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the Software), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit

open class TransitionDriver: UIPercentDrivenInteractiveTransition, UIGestureRecognizerDelegate {
    private weak var presentedController: UIViewController?
    
    private var scrollView: UIScrollView?
    private var panRecognizer: UIPanGestureRecognizer?
    private var scrollViewUpdater: ScrollViewUpdater?
    
    public var direction: TransitionDirection = .present
    
    // MARK: - Linking
    public func link(to controller: UIViewController) {
        presentedController = controller
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleGesture))
        panGesture.delegate = self
        
        panRecognizer = panGesture
        presentedController?.view.addGestureRecognizer(panGesture)
        
        detectScrollView()
    }
    
    // MARK: - Override
    override open var wantsInteractiveStart: Bool {
        get {
            switch direction {
            case .present:
                return false
            case .dismiss:
                return panRecognizer?.state == .began
            }
        }
        
        set {}
    }
    
    @objc private func handleGesture(recognizer: UIPanGestureRecognizer) {
        switch direction {
        case .present:
            handlePresentation(recognizer: recognizer)
        case .dismiss:
            handleDismiss(recognizer: recognizer)
        }
    }
    
    private func detectScrollView() {
        scrollView = presentedController?.view.subviews.first { $0 is UIScrollView } as? UIScrollView
    }
}

// MARK: - Gesture Handling
private extension TransitionDriver {
    var maxTranslation: CGFloat {
        presentedController?.view.frame.height ?? 0
    }
    
    /// `pause()` before call `isRunning`
    var isRunning: Bool {
        percentComplete != 0
    }
    
    func handlePresentation(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            pause()
        case .changed:
            update(percentComplete - recognizer.incrementToBottom(maxTranslation: maxTranslation))
            
        case .ended, .cancelled:
            if recognizer.isProjectedToDownHalf(maxTranslation: maxTranslation) {
                cancel()
            } else {
                finish()
            }
            
        case .failed:
            cancel()
            
        default:
            break
        }
    }
    
    func handleDismiss(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            pause() // Pause allows to detect isRunning
            
            if !isRunning {
                presentedController?.dismiss(animated: true) // Start the new one
            }
            
            if let scrollView = scrollView, let view = presentedController?.view {
                scrollViewUpdater = ScrollViewUpdater(withRootView: view, scrollView: scrollView)
            }
        
        case .changed:
            update(percentComplete + recognizer.incrementToBottom(maxTranslation: maxTranslation))
            
        case .ended, .cancelled:
            scrollViewUpdater = nil
            if recognizer.isProjectedToDownHalf(maxTranslation: maxTranslation) {
                finish()
            } else {
                cancel()
            }

        case .failed:
            cancel()
            
        default:
            break
        }
    }
}

private extension UIPanGestureRecognizer {
    func isProjectedToDownHalf(maxTranslation: CGFloat) -> Bool {
        let endLocation = projectedLocation(decelerationRate: .fast)
        let isPresentationCompleted = endLocation.y > maxTranslation / 2
        
        return isPresentationCompleted
    }
    
    func incrementToBottom(maxTranslation: CGFloat) -> CGFloat {
        let translation = self.translation(in: view).y
        setTranslation(.zero, in: nil)
        
        let percentIncrement = translation / maxTranslation
        return percentIncrement
    }
}

final class ScrollViewUpdater {
    
    // MARK: - Public variables
    
    var isDismissEnabled = false
    
    // MARK: - Private variables
    
    private weak var rootView: UIView?
    private weak var scrollView: UIScrollView?
    private var observation: NSKeyValueObservation?
    
    // MARK: - Initializers
    
    init(withRootView rootView: UIView, scrollView: UIScrollView) {
        self.rootView = rootView
        self.scrollView = scrollView
        self.observation = scrollView.observe(\.contentOffset, options: [.initial], changeHandler: { [weak self] _, _ in
            self?.scrollViewDidScroll()
        })
    }
    
    deinit {
        observation = nil
    }
    
    // MARK: - Private methods
    
    private func scrollViewDidScroll() {
        guard let rootView = rootView, let scrollView = scrollView else {
            return
        }
        
        /// Since iOS 11, the "top" position of a `UIScrollView` is not when
        /// its `contentOffset.y` is 0, but when `contentOffset.y` added to it's
        /// `safeAreaInsets.top` is 0, so that is adjusted for here.
        let offset: CGFloat = {
            if #available(iOS 11, *) {
                return scrollView.contentOffset.y + scrollView.contentInset.top + scrollView.safeAreaInsets.top
            } else {
                return scrollView.contentOffset.y + scrollView.contentInset.top
            }
        }()
        
        /// If the `scrollView` is not at the top, then do nothing.
        /// Additionally, dismissal is not allowed.
        ///
        /// If the `scrollView` is at the top or beyond, but is decelerating,
        /// this means that it reached to the top as the result of momentum from
        /// a swipe. In these cases, in order to retain the "card" effect, we
        /// move the `rootView` and the `scrollView`'s contents to make it
        /// appear as if the entire presented card is shifting down.
        ///
        /// Lastly, if the `scrollView` is at the top or beyond and isn't
        /// decelerating, then that means that the user is panning from top to
        /// bottom and has no more space to scroll within the `scrollView`.
        /// The pan gesture which controls the dismissal is allowed to take over
        /// now, and the scrollView's natural bounce is stopped.
        
        if offset > 0 {
            scrollView.bounces = true
            isDismissEnabled = false
        } else {
            if scrollView.isDecelerating {
                rootView.transform = CGAffineTransform(translationX: 0, y: -offset)
                scrollView.subviews.forEach {
                    $0.transform = CGAffineTransform(translationX: 0, y: offset)
                }
            } else {
                scrollView.bounces = false
                isDismissEnabled = true
            }
        }
    }
    
}
