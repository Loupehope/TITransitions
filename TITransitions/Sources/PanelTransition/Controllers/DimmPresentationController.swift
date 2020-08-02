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

open class DimmPresentationController: PresentationController {
    private let backgroundColor: UIColor
    
    private lazy var dimmView: UIView = {
        let view = UIView()
        view.backgroundColor = backgroundColor
        view.alpha = 0
        return view
    }()
    
    public init(backgroundColor: UIColor,
                driver: TransitionDriver?,
                presentStyle: PresentStyle,
                presentedViewController: UIViewController,
                presenting: UIViewController?) {
        self.backgroundColor = backgroundColor
        super.init(driver: driver,
                   presentStyle: presentStyle,
                   presentedViewController: presentedViewController,
                   presenting: presenting)
    }
    
    override open func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()
        
        containerView?.insertSubview(dimmView, at: 0)
        
        
        performAlongsideTransitionIfPossible { [weak self] in
            self?.dimmView.alpha = 1
        }
    }
    
    override open func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        
        dimmView.frame = containerView?.frame ?? .zero
    }
    
    override open func presentationTransitionDidEnd(_ completed: Bool) {
        super.presentationTransitionDidEnd(completed)
        
        if !completed {
            dimmView.removeFromSuperview()
        }
    }
    
    override open func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()
        
        performAlongsideTransitionIfPossible { [weak self] in
            self?.dimmView.alpha = .zero
        }
    }
    
    override open func dismissalTransitionDidEnd(_ completed: Bool) {
        super.dismissalTransitionDidEnd(completed)
        
        if completed {
            dimmView.removeFromSuperview()
        }
    }
    
    private func performAlongsideTransitionIfPossible(_ block: @escaping () -> Void) {
        guard let coordinator = presentedViewController.transitionCoordinator else {
            block()
            return
        }
            
        coordinator.animate(alongsideTransition: { _ in
            block()
        })
    }
}
