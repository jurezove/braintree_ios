#import "BTPaymentViewController.h"
#import "BTPaymentFormView.h"
#import "BTPaymentActivityOverlayView.h"

#define BT_APP_COLOR [UIColor clearColor]
#define BT_APP_TEXT_COLOR [UIColor colorWithWhite:85/255.0f alpha:1]

#define CELL_BACKGROUND_VIEW_TAG 10
#define CELL_BACKGROUND_VIEW_SHADOW_TAG 11
#define CELL_BORDER_COLOR [[UIColor colorWithWhite:207/255.0f alpha:1] CGColor]

@interface BTPaymentViewController () {
    CGFloat _cornerRadius;
}

@property (assign, nonatomic) BOOL venmoTouchEnabled;
@property (assign, nonatomic) BOOL hasPaymentMethods;

@property (strong, nonatomic) VTClient *client;
@property (strong, nonatomic) BTPaymentActivityOverlayView *paymentActivityOverlayView;
@property (strong, nonatomic) UIView *cellBackgroundView;
@property (strong, nonatomic) UIView *paymentFormFooterView;
@property (strong, nonatomic) UIButton *submitButton;

@end

@implementation BTPaymentViewController

// public
@synthesize delegate;
@synthesize cornerRadius = _cornerRadius;

// private
@synthesize venmoTouchEnabled;
@synthesize hasPaymentMethods;
@synthesize client;
@synthesize paymentFormView;
@synthesize cardView;
@synthesize checkboxCardView;
@synthesize paymentActivityOverlayView;
@synthesize cellBackgroundView;
@synthesize paymentFormFooterView;
@synthesize submitButton;

+ (id)paymentViewControllerWithVenmoTouchEnabled:(BOOL)hasVenmoTouchEnabled {
    BTPaymentViewController *paymentViewController =
    [[BTPaymentViewController alloc] initWithStyle:UITableViewStyleGrouped
                                   hasVenmoTouchEnabled:hasVenmoTouchEnabled];
    return paymentViewController;
}

#pragma mark - UITableViewController

- (id)initWithStyle:(UITableViewStyle)style hasVenmoTouchEnabled:(BOOL)hasVenmoTouchEnabled {
    self = [super initWithStyle:style];
    if (!self) {
        return nil;
    }

    self.title = @"Payment";
    self.venmoTouchEnabled = hasVenmoTouchEnabled;
    return self;
}

#pragma mark - UIViewController

- (void)viewDidUnload {

    [super viewDidUnload];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor colorWithWhite:238/255.0f alpha:1];
    _cornerRadius = 5;

    if (self.venmoTouchEnabled) {
        Class class = NSClassFromString(@"VTClient");
        if (class) {
            self.client = [class sharedClient];
            self.client.delegate = self;

            if (client.paymentMethodOptionStatus == VTPaymentMethodOptionStatusYes) {
                hasPaymentMethods = YES;
            }
        }
    }

    // Section footer view to display the VTCheckboxView view and manual card's submit button
    paymentFormFooterView = [[UIView alloc] initWithFrame:
                           CGRectMake(0, 0, self.view.frame.size.width,
                                      (self.venmoTouchEnabled && self.client ? 120 : 50))];
    paymentFormFooterView.backgroundColor = [UIColor clearColor];

    if (self.venmoTouchEnabled && self.client) {
        // Set up the VTCheckboxView view
        checkboxCardView = [self.client checkboxView];
        [checkboxCardView setOrigin:CGPointMake(10, 0)];
        [checkboxCardView setWidth:300];
        [checkboxCardView setBackgroundColor:[UIColor clearColor]];
        [checkboxCardView setTextColor:[UIColor grayColor]];
        [paymentFormFooterView addSubview:checkboxCardView];
    }

    submitButton = [UIButton buttonWithType:UIButtonTypeCustom];
    submitButton.frame = CGRectMake(10, paymentFormFooterView.frame.size.height - 50, 300, 40);
    submitButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    submitButton.backgroundColor = [UIColor colorWithWhite:222/255.0f alpha:1];
    submitButton.layer.cornerRadius = _cornerRadius;
    submitButton.layer.borderWidth  = 1;
    submitButton.layer.borderColor  = CELL_BORDER_COLOR;
    submitButton.clipsToBounds = YES;
    submitButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [submitButton setTitle:@"Submit" forState:UIControlStateNormal];
    [submitButton setTitleShadowColor:[UIColor whiteColor] forState:UIControlStateNormal];
    submitButton.titleLabel.shadowOffset = CGSizeMake(0, 1);
    [submitButton setTitleColor:[UIColor colorWithWhite:85/255.0f alpha:1]
                       forState:UIControlStateNormal];
    [submitButton setTitleColor:[UIColor colorWithWhite:175/255.0f alpha:1]
                       forState:UIControlStateDisabled];
    [submitButton addTarget:self action:@selector(submitCardInfo:)
           forControlEvents:UIControlEventTouchUpInside];

    UIView *topShadow = [[UIView alloc] initWithFrame:CGRectMake(0, 1, submitButton.frame.size.width, 1)];
    topShadow.backgroundColor = [UIColor colorWithWhite:1 alpha:.1];
    topShadow.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [submitButton addSubview:topShadow];

    [paymentFormFooterView addSubview:submitButton];
    submitButton.enabled = NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - BTPaymentViewController private methods

- (void)prepareForDismissal {
    [paymentActivityOverlayView dismissAnimated:YES];
}

- (void)showErrorWithTitle:(NSString *)title message:(NSString *)message {
    [paymentActivityOverlayView dismissAnimated:NO];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alertView show];
}

#pragma mark - BTPaymentViewController private methods

- (void)submitCardInfo:(UIButton *)button {
    if ([self.delegate respondsToSelector:@selector(paymentViewController:didSubmitCardWithInfo:andCardInfoEncrypted:)]) {
        if (!paymentActivityOverlayView) {
            paymentActivityOverlayView = [BTPaymentActivityOverlayView sharedOverlayView];
        }
        [paymentActivityOverlayView show];

        // Get card info dictionary from the payment form.
        NSDictionary *cardInfo = [self.paymentFormView cardEntry];
        NSDictionary *cardInfoEncrypted;
        if (client && venmoTouchEnabled) {
            // If Venmo Touch, encrypt card info with Braintree's CSE key
            cardInfoEncrypted = [client encryptedCardDataAndVenmoSDKSessionWithCardDictionary:cardInfo];
        }

        [self.delegate paymentViewController:self didSubmitCardWithInfo:cardInfo andCardInfoEncrypted:cardInfoEncrypted];
    }
}

- (void)paymentMethodFound {
    if (hasPaymentMethods) {
        // This case may happen when the user closes the app when viewing the payment form.
        // Open re-opening, [client refresh] will trigger (if no modal is visible) and the
        // cardView would not need animate in again if it already exists.
        cardView = nil;
        [self.tableView reloadData];
    } else {
        hasPaymentMethods = YES;

        [self.tableView insertSections:[NSIndexSet indexSetWithIndex:0]
                      withRowAnimation:UITableViewRowAnimationAutomatic];

        [self performSelector:@selector(reloadTitle) withObject:nil afterDelay:.3];
    }
}

- (void)logoutVenmoSDK {
    if ([self.tableView numberOfSections] == 2) {
        hasPaymentMethods = NO;
        [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0]
                      withRowAnimation:UITableViewRowAnimationAutomatic];
        [self performSelector:@selector(reloadTitle) withObject:nil afterDelay:.3];
    }
}

- (void)reloadTitle {
    [self.tableView reloadData];

    // webview is causing a crash when it exists in a table footer view and you reload a particular section
    // look like a bug with Apple.
    // http://stackoverflow.com/questions/11626572/uiwebview-as-view-for-footer-in-section-for-tableview-strange-crash-crash-log
    //    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:(hasPaymentMethods ? 1 : 0)]
    //                  withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 81 = height for VTCardView, 40 = height of enter card manually cell
    return (hasPaymentMethods && indexPath.section == 0 ? 81 : 40);
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (hasPaymentMethods && section == 0) {
        // VTCardView
        return 0.5f;
    } else {
        // BTPaymentFormView
        return (self.venmoTouchEnabled ? 120 : 50);
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    // VTCardView has no footer view.
    // Payment form view has submit button and perhaps VTCheckboxView
    return (hasPaymentMethods && section == 0 ? nil : paymentFormFooterView);
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (hasPaymentMethods ? 2 : 1);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

// Don't use "tableView:titleForHeaderInSection:" because titles don't auto-update when
// number of sections update.
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 40)];
    view.backgroundColor = BT_APP_COLOR;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 280, 20)];
    titleLabel.backgroundColor = BT_APP_COLOR;
    titleLabel.textColor = BT_APP_TEXT_COLOR;
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.shadowOffset = CGSizeMake(0, 1);
    [view addSubview:titleLabel];
    
    if (hasPaymentMethods && section == 0) {
        titleLabel.text = @"Use a Saved Card";
    } else {
        titleLabel.text = (hasPaymentMethods ? @"Or, Add a New Card" : @"Add a New Card");
    }
    
    return view;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *UseCardCell         = @"UseCardCell";
    static NSString *PaymentFormViewCell = @"PaymentFormViewCell";

    NSString *currentCellIdentifier;
    if (hasPaymentMethods && indexPath.section == 0) {
        currentCellIdentifier = UseCardCell;
    } else {
        currentCellIdentifier = PaymentFormViewCell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UseCardCell];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:currentCellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        if ([currentCellIdentifier isEqualToString:PaymentFormViewCell]) {
            [self setUpPaymentFormViewForCell:cell];
        }
    }

    if ([currentCellIdentifier isEqualToString:UseCardCell]) {
        [self setUpCardViewForCell:cell];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (hasPaymentMethods && indexPath.section == 0) {
        // Venmo Touch row
        cell.backgroundView = nil;
    }
    else {
        // Customize the cell background view
        if (cell.backgroundView.tag != CELL_BACKGROUND_VIEW_TAG) {
            cellBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
            cellBackgroundView.backgroundColor = [UIColor whiteColor];
            cellBackgroundView.tag = CELL_BACKGROUND_VIEW_TAG;
            cellBackgroundView.layer.cornerRadius  = _cornerRadius;
            cellBackgroundView.layer.borderColor   = CELL_BORDER_COLOR;
            cellBackgroundView.layer.borderWidth   = 1;
            cellBackgroundView.layer.shadowRadius  = 1;
            cellBackgroundView.layer.shadowOpacity = 1;
            cellBackgroundView.layer.shadowColor   = [[UIColor whiteColor] CGColor];
            cellBackgroundView.layer.shadowOffset  = CGSizeMake(0, 1);
            cellBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

            UIView *topShadowView = [[UIView alloc] initWithFrame:CGRectMake(3, 1, cellBackgroundView.frame.size.width - 6, 1)];
            topShadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            topShadowView.backgroundColor = [UIColor colorWithWhite:0 alpha:.1];
            topShadowView.tag = CELL_BACKGROUND_VIEW_SHADOW_TAG;
            [cellBackgroundView addSubview:topShadowView];

            cell.backgroundView = nil;
            cell.backgroundView = cellBackgroundView;

            [self setUpPaymentFormViewForCell:cell];
        }
    }
}

- (void)setUpCardViewForCell:(UITableViewCell *)cell {
    if (!cardView) {
        cardView = [self.client cardView];
    }
    if (cardView && cell) {
        [cardView setOrigin:CGPointMake(0, 0)];
        [cardView setBackgroundColor:[UIColor clearColor]];
        [cardView setWidth:300];
        [cell.contentView addSubview:cardView];
    }
}

- (void)setUpPaymentFormViewForCell:(UITableViewCell *)cell {
    if (!self.paymentFormView) {
        self.paymentFormView = [BTPaymentFormView paymentFormView];
        self.paymentFormView.delegate = self;
        self.paymentFormView.backgroundColor = [UIColor clearColor];
    }

    [paymentFormView removeFromSuperview];
    [cell.contentView addSubview:paymentFormView];
}


#pragma mark - BTPaymentFormViewDelegate

- (void)paymentFormView:(BTPaymentFormView *)paymentFormView didModifyCardInformationWithValidity:(BOOL)isValid {
    submitButton.enabled = isValid;
}

#pragma mark - VTClientDelegate

- (void)client:(VTClient *)client didReceivePaymentMethodOptionStatus:(VTPaymentMethodOptionStatus)paymentMethodOptionStatus {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    NSLog(@"loading finished: %i", paymentMethodOptionStatus);
    if (paymentMethodOptionStatus == VTPaymentMethodOptionStatusYes) {
        // Force tableview to reloadData, which renders VTCardView
        NSLog(@"payment method on file");
        [self paymentMethodFound];
    } else if (hasPaymentMethods && paymentMethodOptionStatus != VTPaymentMethodOptionStatusYes) {
        hasPaymentMethods = NO;
        [self.tableView reloadData];
    }
}

- (void)client:(VTClient *)client didFinishLoadingLiveStatus:(VTLiveStatus)liveStatus {
    NSLog(@"didFinishLoadingLiveStatus: %i", liveStatus);
}

- (void)client:(VTClient *)client approvedPaymentMethodWithCode:(NSString *)paymentMethodCode {
    // Return it to the delegate
    if ([self.delegate respondsToSelector:
         @selector(paymentViewController:didAuthorizeCardWithPaymentMethodCode:)]) {
        if (!paymentActivityOverlayView) {
            paymentActivityOverlayView = [BTPaymentActivityOverlayView sharedOverlayView];
            [paymentActivityOverlayView show];
        }

        [delegate paymentViewController:self didAuthorizeCardWithPaymentMethodCode:paymentMethodCode];
    }
}

- (void)clientDidLogout:(VTClient *)client {
    [self logoutVenmoSDK];
}

#pragma mark - UI Customization

- (void)setCornerRadius:(CGFloat)cornerRadius {
    if (!(0 <= cornerRadius && cornerRadius >= 15)) {
        return;
    }
    
    _cornerRadius = cornerRadius;
    [cardView setCornerRadius:_cornerRadius];
    cellBackgroundView.layer.cornerRadius  =
    submitButton.layer.cornerRadius  = _cornerRadius;

    // Set the background cell's top shadow width.
    UIView *topShadowView = [cellBackgroundView viewWithTag:CELL_BACKGROUND_VIEW_SHADOW_TAG];
    CGFloat topShadowBuffer = ceilf(_cornerRadius/2);
    CGRect topShadowFrame = CGRectMake(topShadowBuffer, 1, cellBackgroundView.frame.size.width - topShadowBuffer*2, 1);
    topShadowView.frame = topShadowFrame;
}

@end
