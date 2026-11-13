// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get home => 'Home';

  @override
  String get orders => 'Work Orders';

  @override
  String get customers => 'Customers';

  @override
  String get devices => 'Devices';

  @override
  String get services => 'Services';

  @override
  String get products => 'Products';

  @override
  String get reports => 'Reports';

  @override
  String get settings => 'Settings';

  @override
  String get profile => 'Profile';

  @override
  String get company => 'Company';

  @override
  String get team => 'Team';

  @override
  String get collaborators => 'Team members';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get create => 'Create';

  @override
  String get update => 'Update';

  @override
  String get search => 'Search';

  @override
  String get searchOrAddNew => 'Search or add new';

  @override
  String get filter => 'Filter';

  @override
  String get sort => 'Sort';

  @override
  String get refresh => 'Refresh';

  @override
  String get close => 'Close';

  @override
  String get confirm => 'Confirm';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get previous => 'Previous';

  @override
  String get done => 'Done';

  @override
  String get finish => 'Finish';

  @override
  String get loading => 'Loading...';

  @override
  String get send => 'Send';

  @override
  String get share => 'Share';

  @override
  String get copy => 'Copy';

  @override
  String get print => 'Print';

  @override
  String get preview => 'Preview';

  @override
  String get export => 'Export';

  @override
  String get import => 'Import';

  @override
  String get select => 'Select';

  @override
  String get selectAll => 'Select All';

  @override
  String get clear => 'Clear';

  @override
  String get reset => 'Reset';

  @override
  String get apply => 'Apply';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get more => 'More';

  @override
  String get less => 'Less';

  @override
  String get details => 'Details';

  @override
  String get options => 'Options';

  @override
  String get actions => 'Actions';

  @override
  String get status => 'Status';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusInProgress => 'In Progress';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusQuote => 'Quote';

  @override
  String get payments => 'Payments';

  @override
  String get payment => 'Payment';

  @override
  String get paid => 'Paid';

  @override
  String get unpaid => 'Unpaid';

  @override
  String get toReceive => 'Still to pay';

  @override
  String get received => 'Received';

  @override
  String get pix => 'PIX';

  @override
  String get check => 'Check';

  @override
  String get installments => 'Installments';

  @override
  String get installment => 'Installment';

  @override
  String get dueDate => 'Due Date';

  @override
  String get paymentCannotExceedBalance => 'Payment cannot exceed balance';

  @override
  String get discountCannotExceedBalance => 'Discount cannot exceed balance';

  @override
  String get asaasTransactionCannotBeRemoved =>
      'Payments received through Asaas can\'t be removed here. To undo one, refund the charge in Asaas.';

  @override
  String get paymentUpdateFailed =>
      'Couldn\'t save the payment. Check your connection and try again.';

  @override
  String get paymentExceedsBalance =>
      'The amount is more than what\'s left to receive. Check it and try again.';

  @override
  String get paymentRequiresConnection =>
      'No connection. Try again when you\'re online.';

  @override
  String get history => 'History';

  @override
  String get valueMustBeGreaterThanZero => 'Value must be greater than zero';

  @override
  String confirmRemoveTransaction(String type, String amount) {
    return 'Do you want to remove this $type of $amount?';
  }

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get invalidPhone => 'Invalid phone';

  @override
  String get invalidFormat => 'Invalid format';

  @override
  String get minimum => 'Minimum';

  @override
  String get maximum => 'Maximum';

  @override
  String get characters => 'characters';

  @override
  String get noValuesRegistered => 'No values registered';

  @override
  String get typeAboveToAdd => 'Type above to add';

  @override
  String minLength(int count) {
    return 'Minimum $count characters';
  }

  @override
  String maxLength(int count) {
    return 'Maximum $count characters';
  }

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get changePhoto => 'Change Photo';

  @override
  String get removePhoto => 'Remove Photo';

  @override
  String get addPhoto => 'Add Photo';

  @override
  String get photos => 'photos';

  @override
  String get photo => 'Photo';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get scheduledDate => 'Scheduled';

  @override
  String get updatedAt => 'Updated at';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get startDate => 'Start date';

  @override
  String get endDate => 'End date';

  @override
  String get period => 'Period';

  @override
  String get confirmDelete => 'Confirm Deletion';

  @override
  String confirmDeleteMessageNamed(String name) {
    return 'Do you really want to delete \"$name\"?';
  }

  @override
  String get confirmAction => 'Confirm Action';

  @override
  String get cannotUndo => 'This action cannot be undone.';

  @override
  String get discard => 'Discard';

  @override
  String get leave => 'Leave';

  @override
  String get stay => 'Stay';

  @override
  String get customer => 'Customer';

  @override
  String get newCustomer => 'New Customer';

  @override
  String get editCustomer => 'Edit Customer';

  @override
  String get customerName => 'Customer Name';

  @override
  String get customerList => 'Customer List';

  @override
  String get addCustomer => 'Add Customer';

  @override
  String get name => 'Name';

  @override
  String get fullName => 'Full Name';

  @override
  String get phone => 'Phone';

  @override
  String get whatsapp => 'WhatsApp';

  @override
  String get email => 'Email';

  @override
  String get address => 'Address';

  @override
  String get number => 'Number';

  @override
  String get city => 'City';

  @override
  String get state => 'State';

  @override
  String get country => 'Country';

  @override
  String get notes => 'Notes';

  @override
  String get observation => 'Observation';

  @override
  String get description => 'Description';

  @override
  String get comments => 'Comments';

  @override
  String get document => 'Document';

  @override
  String get cpfCnpj => 'CPF/CNPJ';

  @override
  String get order => 'Work Order';

  @override
  String get orderShort => 'WO';

  @override
  String get orderOverdue => 'Overdue';

  @override
  String get newOrder => 'NEW';

  @override
  String get orderNumber => 'Order Number';

  @override
  String get orderList => 'Order List';

  @override
  String get addOrder => 'Add Order';

  @override
  String get createOrder => 'Create Order';

  @override
  String get technician => 'Technician';

  @override
  String get technicians => 'Technicians';

  @override
  String get problem => 'Reported Problem';

  @override
  String get warranty => 'Warranty';

  @override
  String get priority => 'Priority';

  @override
  String get device => 'Device';

  @override
  String get deviceCategory => 'Category';

  @override
  String get editDevice => 'Edit Device';

  @override
  String get deviceList => 'Device List';

  @override
  String get addDevice => 'Add Device';

  @override
  String get brand => 'Brand';

  @override
  String get model => 'Model';

  @override
  String get serialNumber => 'Serial Number';

  @override
  String get color => 'Color';

  @override
  String get condition => 'Condition';

  @override
  String get defects => 'Defects';

  @override
  String get service => 'Service';

  @override
  String get editService => 'Edit Service';

  @override
  String get serviceList => 'Service List';

  @override
  String get searchService => 'Search Service';

  @override
  String get addService => 'Add Service';

  @override
  String get product => 'Product';

  @override
  String get editProduct => 'Edit Product';

  @override
  String get productList => 'Product List';

  @override
  String get searchProduct => 'Search Product';

  @override
  String get addProduct => 'Add Product';

  @override
  String get barcode => 'Barcode';

  @override
  String get unit => 'Unit';

  @override
  String get category => 'Category';

  @override
  String get categories => 'Categories';

  @override
  String get total => 'Total';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get discount => 'Discount';

  @override
  String get discountValue => 'Discount Value';

  @override
  String get price => 'Price';

  @override
  String get quantity => 'Quantity';

  @override
  String get value => 'Value';

  @override
  String get amount => 'Amount';

  @override
  String get tax => 'Tax';

  @override
  String get balance => 'Balance';

  @override
  String get totalPaid => 'Total Paid';

  @override
  String get remaining => 'Remaining';

  @override
  String get change => 'Change';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get tryAgain => 'Try again';

  @override
  String get noInternetConnection => 'No internet connection';

  @override
  String get permissionDenied => 'Permission denied';

  @override
  String get timeout => 'Timeout';

  @override
  String get login => 'Sign In';

  @override
  String get logout => 'Sign Out';

  @override
  String get logoutConfirm => 'Do you really want to sign out?';

  @override
  String get signIn => 'Sign In';

  @override
  String get password => 'Password';

  @override
  String get emailSent => 'Email sent';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get termsAndConditions => 'Terms and Conditions';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get companyName => 'Company Name';

  @override
  String get skip => 'Skip';

  @override
  String get continue_ => 'Continue';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get theme => 'Theme';

  @override
  String get notifications => 'Notifications';

  @override
  String get markAllAsRead => 'Mark all';

  @override
  String get sound => 'Sound';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get support => 'Support';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get analytics => 'Analytics';

  @override
  String get revenue => 'Revenue';

  @override
  String get recentOrders => 'Recent orders';

  @override
  String get role => 'Role';

  @override
  String get noRole => 'No role';

  @override
  String get roles => 'Roles';

  @override
  String get owner => 'Owner';

  @override
  String get admin => 'Administrator';

  @override
  String get manager => 'Manager';

  @override
  String get viewer => 'Viewer';

  @override
  String get permissions => 'Permissions';

  @override
  String get canCreate => 'Can Create';

  @override
  String get canEdit => 'Can Edit';

  @override
  String get canDelete => 'Can Delete';

  @override
  String get canView => 'Can View';

  @override
  String get checklist => 'Checklist';

  @override
  String get checklists => 'Checklists';

  @override
  String get customerSignature => 'Customer Signature';

  @override
  String get required => 'Required';

  @override
  String get optional => 'Optional';

  @override
  String get complete => 'Complete';

  @override
  String get answered => 'Answered';

  @override
  String get notAnswered => 'Not Answered';

  @override
  String get quote => 'Quote';

  @override
  String get quotes => 'Quotes';

  @override
  String expiresIn(int days) {
    return 'Expires in $days days';
  }

  @override
  String get expired => 'Expired';

  @override
  String get inactive => 'Inactive';

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get visible => 'Visible';

  @override
  String get hidden => 'Hidden';

  @override
  String get public => 'Public';

  @override
  String get private => 'Private';

  @override
  String get draft => 'Draft';

  @override
  String get deleted => 'Deleted';

  @override
  String get all => 'All';

  @override
  String get none => 'None';

  @override
  String get other => 'Other';

  @override
  String get others => 'Others';

  @override
  String get custom => 'Custom';

  @override
  String get old => 'Old';

  @override
  String get recent => 'Recent';

  @override
  String get byContinuingYouAgree => 'By continuing, you agree to our';

  @override
  String get error => 'Error';

  @override
  String get companyNotFound => 'Company not found';

  @override
  String get companyNoSegment => 'Company has no segment defined';

  @override
  String get userNotFound => 'User not found';

  @override
  String get checkInboxResetPassword =>
      'Check your inbox to reset your password.';

  @override
  String get user => 'User';

  @override
  String get switchCompany => 'Switch account';

  @override
  String get management => 'Management';

  @override
  String get integrations => 'Integrations';

  @override
  String get integrationsEmpty => 'No connections yet';

  @override
  String get integrationsNew => 'New connection';

  @override
  String get integrationsNameHint => 'e.g. My ChatGPT';

  @override
  String get integrationsUrlOnce =>
      'Copy this URL now. It will not be shown again.';

  @override
  String get integrationsCopy => 'Copy URL';

  @override
  String get integrationsRevoke => 'Turn off connection';

  @override
  String get integrationsRevokeConfirm =>
      'Revoke this connection? Anyone using this URL loses access.';

  @override
  String get integrationsNeverUsed => 'Never used';

  @override
  String integrationsLastUsed(String date) {
    return 'Last used on $date';
  }

  @override
  String get integrationsErrorForbidden =>
      'Only owners and admins can manage integrations.';

  @override
  String get integrationsErrorNotFound => 'This connection no longer exists.';

  @override
  String get integrationsErrorGeneric =>
      'Something went wrong. Please try again.';

  @override
  String get companyData => 'Details for customers';

  @override
  String get account => 'Account';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get automatic => 'Automatic';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get selectCompany => 'Choose account';

  @override
  String get companyNoName => 'Unnamed account';

  @override
  String get deleteAccountWarning =>
      'This action is permanent and cannot be undone.\n\nAll your data, including work orders, customers and settings will be permanently removed.\n\nAre you sure you want to continue?';

  @override
  String get finalConfirmation => 'Final Confirmation';

  @override
  String get lastChanceCancel =>
      'This is your last chance to cancel.\n\nConfirm the permanent deletion of your account?';

  @override
  String get permanentlyDelete => 'Permanently Delete';

  @override
  String get errorDeletingAccount => 'Error Deleting Account';

  @override
  String get couldNotDeleteAccount => 'Could not delete your account.';

  @override
  String get accountDeletionTakingLong =>
      'Deleting your account can take a few minutes. Try again in a moment.';

  @override
  String get requiresRecentLogin =>
      'For security, Firebase requires a recent login before deleting the account.\n\nPlease:\n1. Log out of your account\n2. Log in again\n3. Try to delete the account immediately after logging in';

  @override
  String get noPermissionDelete =>
      'You don\'t have permission to delete your account. Please try again later.';

  @override
  String get networkError =>
      'Connection error. Check your internet and try again.';

  @override
  String get reauthenticationRequired => 'Re-authentication Required';

  @override
  String get pleaseSignInAgainToDelete =>
      'For security reasons, you need to sign in again before deleting your account.';

  @override
  String get signInAgain => 'Sign In Again';

  @override
  String get authenticated => 'Authenticated';

  @override
  String get reauthenticationFailed => 'Re-authentication Failed';

  @override
  String get couldNotReauthenticate => 'Could not re-authenticate.';

  @override
  String get remove => 'Remove';

  @override
  String get noPermission => 'No Permission';

  @override
  String get noPermissionToRemove =>
      'You don\'t have permission to remove this item.';

  @override
  String get noSegmentsAvailable => 'No segments available';

  @override
  String get specialties => 'Specialties';

  @override
  String get myCompany => 'Settings';

  @override
  String get retryAgain => 'Try again';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get unitValue => 'Unit value';

  @override
  String get setAsCover => 'Set as cover';

  @override
  String get roleDescAdmin =>
      'Full access. Handles settings and the team, and sees all data.';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleDescSupervisor =>
      'Coordinates teams and equipment. Does not view financial values.';

  @override
  String get roleSupervisor => 'Supervisor';

  @override
  String get roleDescManager =>
      'Focus on results. Views billing and costs, but does not execute services.';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleDescConsultant =>
      'Creates quotes. Views prices, but accesses only their own Service Orders.';

  @override
  String get roleConsultant => 'Consultant';

  @override
  String get roleDescTechnician =>
      'Executes services. Does not view prices and has limited editing after SO approval.';

  @override
  String get roleTechnician => 'Technician';

  @override
  String get registered => 'registered';

  @override
  String get errorLoading => 'Error loading';

  @override
  String get tapPlusToAddYourFirst => 'Tap + to add your first';

  @override
  String get doYouWantToRemoveThe => 'Do you want to remove the';

  @override
  String get pending => 'Pending';

  @override
  String get cancelInvite => 'Cancel Invite';

  @override
  String get userWithoutName => 'User without name';

  @override
  String get removeCollaborator => 'Remove Collaborator';

  @override
  String get emailNotProvided => 'Email not provided';

  @override
  String get emailPlaceholder => 'email@example.com';

  @override
  String get collaboratorAdded => 'Collaborator Added';

  @override
  String get financial => 'Financial';

  @override
  String get financialAccessDenied =>
      'You don\'t have permission to access the financial dashboard.\\n\\nOnly Administrators and Managers can view financial data.';

  @override
  String get week => 'Week';

  @override
  String get month => 'Month';

  @override
  String get year => 'Year';

  @override
  String get currentMonth => 'Current month';

  @override
  String get currentYear => 'Current year';

  @override
  String get start => 'Start';

  @override
  String get end => 'End';

  @override
  String get billing => 'Sold';

  @override
  String get composition => 'Composition';

  @override
  String get customersReceived => 'Customers who paid';

  @override
  String get customersToReceive => 'Customers with a balance';

  @override
  String get customerWithoutName => 'Customer without name';

  @override
  String get serviceWithoutName => 'Service without name';

  @override
  String get productWithoutName => 'Product without name';

  @override
  String get seeLess => 'See less';

  @override
  String seeAllCount(int count) {
    return 'See all ($count)';
  }

  @override
  String get errorGeneratingReport => 'Error generating report';

  @override
  String get pendingPayment => 'Pending';

  @override
  String get contacts => 'Contacts';

  @override
  String get preparing => 'Preparing...';

  @override
  String get changeLogo => 'Change Logo';

  @override
  String get companyNamePlaceholder => 'Name shown on orders';

  @override
  String get companyEmailPlaceholder => 'contact@company.com';

  @override
  String get phonePlaceholder => '(00) 00000-0000';

  @override
  String get fullAddress => 'Full address';

  @override
  String get websitePlaceholder => 'www.company.com';

  @override
  String get segment => 'Segment';

  @override
  String get website => 'Website';

  @override
  String get noName => 'No name';

  @override
  String get errorSendingPhoto => 'Error Sending Photo';

  @override
  String get couldNotSendPhoto => 'Could not send photo. Please try again.';

  @override
  String get errorSendingPhotos => 'Error Sending Photos';

  @override
  String get couldNotSendPhotos => 'Could not send photos. Please try again.';

  @override
  String get requiredFields => 'Required Fields';

  @override
  String get pleaseFill => 'Please fill in:';

  @override
  String get couldNotCompleteForm =>
      'Could not complete the procedure. Please try again.';

  @override
  String get noPermissionReopenForm =>
      'Only Administrators, Managers and Supervisors can reopen completed procedures.';

  @override
  String get couldNotReopenForm =>
      'Could not reopen the procedure. Please try again.';

  @override
  String get type => 'Type';

  @override
  String get errorLoadingPhoto => 'Error loading photo';

  @override
  String get reopen => 'Reopen';

  @override
  String get typeOneOptionPerLine => 'Type one option per line';

  @override
  String get searchProcedure => 'Search procedure';

  @override
  String get noProceduresAvailable => 'No procedures available';

  @override
  String get fromCompany => 'From your company';

  @override
  String get global => 'Global';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'items',
      one: 'item',
    );
    return '$count $_temp0';
  }

  @override
  String importConfirmationMessage(String title) {
    return 'Do you want to import the procedure \"$title\" to your company?\n\nYou will be able to edit it after import.';
  }

  @override
  String get errorLoadingProcedures => 'Error loading procedures';

  @override
  String get importProcedure => 'Import Procedure';

  @override
  String get importForMyCompany => 'Import to my account';

  @override
  String get couldNotImportProcedure =>
      'Could not import the procedure. Please try again.';

  @override
  String get procedureImportedSuccessfully =>
      'Procedure imported successfully!';

  @override
  String get closeDialog => 'Close';

  @override
  String get companyLogo => 'Company Logo';

  @override
  String get information => 'INFORMATION';

  @override
  String get pendingInvites => 'Pending Invites';

  @override
  String get noPendingInvites => 'No pending invites';

  @override
  String get acceptInvite => 'Accept';

  @override
  String get rejectInvite => 'Reject Invite';

  @override
  String get inviteAccepted => 'Invite Accepted';

  @override
  String youAreNowPartOf(String company) {
    return 'You are now part of $company!';
  }

  @override
  String areYouSureReject(String company) {
    return 'Are you sure you want to reject the invite from $company?';
  }

  @override
  String get or => 'or';

  @override
  String get reject => 'Reject';

  @override
  String invitedBy(String name) {
    return 'Invited by $name';
  }

  @override
  String roleLabel(String role) {
    return 'Role: $role';
  }

  @override
  String get inviteExpired => 'This invite has expired';

  @override
  String get inviteCancelled => 'This invite was cancelled';

  @override
  String get inviteNotFound => 'Invite not found';

  @override
  String get inviteAlreadyUsed => 'This invite has already been used';

  @override
  String get enterInviteCode => 'Enter invite code';

  @override
  String get enterCodeReceived =>
      'Enter the code you received to join the team';

  @override
  String get searchAnotherCode => 'Search another code';

  @override
  String get inviteCodeCopied => 'Invite code copied!';

  @override
  String get emailOrPhone => 'Enter email or phone';

  @override
  String get thisWillRemoveAllPayments =>
      'This will remove all recorded payments and discounts. Do you want to continue?';

  @override
  String get attention => 'Attention';

  @override
  String get financialReport => 'Financial report';

  @override
  String get totalBilling => 'Sold';

  @override
  String get financialSummary => 'Financial Summary';

  @override
  String get averageTicket => 'Average per order';

  @override
  String get customerRanking => 'Customer Ranking';

  @override
  String get serviceRanking => 'Service Ranking';

  @override
  String get productRanking => 'Product Ranking';

  @override
  String get paidOrders => 'Paid Orders';

  @override
  String get ordersToReceive => 'Orders with a balance';

  @override
  String get vehicle => 'Vehicle';

  @override
  String get valueColumn => 'Value';

  @override
  String get statusColumn => 'Status';

  @override
  String get quantityShort => 'Qty';

  @override
  String get noOrdersInPeriod => 'No orders in this period';

  @override
  String get notInformed => 'Not informed';

  @override
  String nOrdersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'orders',
      one: 'order',
    );
    return '$count $_temp0';
  }

  @override
  String nItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'items',
      one: 'item',
    );
    return '$count $_temp0';
  }

  @override
  String get orderSingular => 'order';

  @override
  String get orderPlural => 'orders';

  @override
  String generatedAt(String date) {
    return 'Generated on $date';
  }

  @override
  String pageOf(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get preparingReport => 'Preparing report...';

  @override
  String get appTagline => 'Work Order Management System';

  @override
  String receivedWithPercent(String percent) {
    return 'Already paid ($percent%)';
  }

  @override
  String toReceiveWithPercent(String percent) {
    return 'Still to pay ($percent%)';
  }

  @override
  String get generatedByPraticos => 'Generated by PraticOS';

  @override
  String get serviceDescriptionColumn => 'SERVICE DESCRIPTION';

  @override
  String get descriptionColumn => 'DESCRIPTION';

  @override
  String get unitShort => 'UNIT';

  @override
  String get alreadyPaid => 'Already paid';

  @override
  String get remainingBalance => 'REMAINING BALANCE';

  @override
  String get totalToPay => 'TOTAL TO PAY';

  @override
  String get photosAvailableDigitally =>
      'Photos available in the digital system';

  @override
  String attachedPhotosCount(int count) {
    return 'Attached Photos ($count)';
  }

  @override
  String get photoRecord => 'PHOTO RECORD';

  @override
  String get partsAndProducts => 'PARTS AND PRODUCTS';

  @override
  String nPhotosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'photos',
      one: 'photo',
    );
    return '$count $_temp0';
  }

  @override
  String get notSelected => 'Not selected';

  @override
  String formLabelWithTitle(String title) {
    return 'Form: $title';
  }

  @override
  String get linked => 'Linked';

  @override
  String get linkWhatsApp => 'Link WhatsApp';

  @override
  String get linkWhatsAppDescription =>
      'Scan the QR code or tap the button to open WhatsApp and send the linking code to the PraticOS bot.';

  @override
  String linkExpiresIn(String time) {
    return 'Expires in $time';
  }

  @override
  String get openWhatsApp => 'Open WhatsApp';

  @override
  String get errorGeneratingToken => 'Error generating linking code';

  @override
  String get copyLink => 'Copy Link';

  @override
  String get shareLink => 'Share Link';

  @override
  String get linkCopied => 'Link copied!';

  @override
  String viewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'views',
      one: 'view',
    );
    return '$count $_temp0';
  }

  @override
  String get commentPlaceholder => 'Type your comment...';

  @override
  String get commentFromCustomer => 'Customer';

  @override
  String get commentFromTeam => 'Team';

  @override
  String get rejectionReason => 'Rejection reason';

  @override
  String get days => 'days';

  @override
  String get rating => 'Rating';

  @override
  String get ratings => 'Ratings';

  @override
  String get noRatingsYet => 'No ratings yet';

  @override
  String get notNow => 'Not now';

  @override
  String get connectWhatsApp => 'Connect your WhatsApp';

  @override
  String get connectWhatsAppBannerDescription =>
      'Receive notifications, manage work orders and send updates to customers via WhatsApp.';

  @override
  String get whatsappOnboardingTitle => 'Connect your WhatsApp';

  @override
  String get whatsappOnboardingSubtitle =>
      'Get the most out of PraticOS by connecting your WhatsApp';

  @override
  String get whatsappBenefitNotifications =>
      'Receive notifications for new work orders';

  @override
  String get whatsappBenefitManage => 'Manage work orders directly via chat';

  @override
  String get whatsappBenefitClients => 'Send updates to customers';

  @override
  String get linkNow => 'Link now';

  @override
  String get maybeLater => 'Maybe later';

  @override
  String inviteWhatsAppMessage(String code) {
    return 'You have been invited to the team on PraticOS!\n\nInvite code: $code\n\nDownload the app:\niOS: https://apps.apple.com/br/app/praticos/id1534604555\nAndroid: https://play.google.com/store/apps/details?id=br.com.rafsoft.praticos';
  }

  @override
  String get cannotRemoveOnlyAdmin =>
      'You can\'t remove the only administrator. Make someone else an administrator first.';

  @override
  String get cannotChangeOnlyAdminRole =>
      'Cannot change the only administrator\'s role. Promote another collaborator to administrator first.';

  @override
  String get cannotChangeOwner =>
      'The company owner\'s role can\'t be changed and the owner can\'t be removed.';

  @override
  String get teamActionNotAllowed =>
      'Only the owner or an administrator can change the team.';

  @override
  String get teamActionFailed =>
      'Couldn\'t save the team change. Please try again.';

  @override
  String get cannotRemoveSelf => 'You cannot remove yourself from the team.';

  @override
  String get invalidInviteCompanyNotFound =>
      'Invalid invite: company not found.';

  @override
  String get duplicateInviteTitle => 'Existing Invite';

  @override
  String get duplicateInviteMessage =>
      'There is already a pending invite for this email/phone.';

  @override
  String get resendExistingInvite => 'Resend Existing';

  @override
  String get cancelAndCreateNew => 'Cancel and Create New';

  @override
  String get agenda => 'Schedule';

  @override
  String get noScheduledOrders => 'No orders scheduled for this day';

  @override
  String get allTeam => 'Whole team';

  @override
  String get allDay => 'All day';

  @override
  String get scheduleReminder => 'Schedule reminder';

  @override
  String get reminderDisabled => 'Disabled';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min before';
  }

  @override
  String get reminderHourBefore => '1 hour before';

  @override
  String reminderHoursBefore(int hours) {
    return '$hours hours before';
  }

  @override
  String get inviteWhatsAppSuccessTitle => 'Collaborator Invited';

  @override
  String inviteWhatsAppSuccessMessage(String name) {
    return '$name will automatically receive the invite when they contact the PraticOS bot on WhatsApp.';
  }

  @override
  String get serviceLocation => 'Service Location';

  @override
  String get openInMaps => 'Open in Maps';

  @override
  String get addressPlaceholder => 'Street, number, neighborhood, city';

  @override
  String get sendWhatsApp => 'Send WhatsApp';

  @override
  String inviteWhatsAppBotMessage(String company) {
    return 'Hello! You have been added to the $company team on PraticOS. Send a \"hi\" to the bot to get started: https://wa.me/5548988794742';
  }

  @override
  String get removeDevice => 'Remove Device';

  @override
  String get generalNoDevice => 'General';

  @override
  String get selectDeviceFor => 'For which device?';

  @override
  String deviceCount(int count) {
    return '$count devices';
  }

  @override
  String get features => 'Features';

  @override
  String get contracts => 'Contracts';

  @override
  String get noContracts => 'No contracts';

  @override
  String get recurringContract => 'Recurring contract';

  @override
  String get contractNextDue => 'Next generation';

  @override
  String generatedOrdersCount(int count) {
    return 'Generated orders ($count)';
  }

  @override
  String get selectDate => 'Select date';

  @override
  String get deviceStatusActive => 'Active';

  @override
  String get deviceStatusMaintenance => 'Under maintenance';

  @override
  String get deviceStatusInactive => 'Inactive';

  @override
  String get deviceStatusDecommissioned => 'Decommissioned';

  @override
  String get noOrderHistory => 'No work orders recorded';

  @override
  String get configure => 'Configure';

  @override
  String get interval => 'Interval';

  @override
  String get indefinite => 'Indefinite';

  @override
  String get noOrdersDueOnDate => 'No orders due on this day';

  @override
  String get documents => 'Documents';

  @override
  String get addDocument => 'Add Document';

  @override
  String get receipt => 'Receipt';

  @override
  String get invoice => 'Invoice';

  @override
  String get contract => 'Contract';

  @override
  String get deleteDocument => 'Delete Document';

  @override
  String get confirmDeleteDocument =>
      'Are you sure you want to delete this document?';

  @override
  String get documentAdded => 'Document added';

  @override
  String get openDocument => 'Open';

  @override
  String get fromFiles => 'Files';

  @override
  String get errorUploadingDocument => 'Error uploading document';

  @override
  String get engagementReminders => 'Reminders';

  @override
  String get dailyNotificationTitle => 'Good morning!';

  @override
  String get dailyNotificationBody => 'Log today\'s work orders on PraticOS';

  @override
  String get inactivity3dTitle => 'We miss you!';

  @override
  String get inactivity3dBody =>
      'You haven\'t opened PraticOS in 3 days. How about logging your orders?';

  @override
  String get inactivity5dTitle => 'Your orders are waiting!';

  @override
  String get inactivity5dBody =>
      'It\'s been 5 days! Don\'t lose track of your work orders.';

  @override
  String get inactivity7dTitle => 'Don\'t let PraticOS sit idle!';

  @override
  String get inactivity7dBody =>
      'It\'s been 1 week since you opened the app. Come back and organize your orders!';

  @override
  String get pendingOsNotificationTitle => 'Pending orders need attention';

  @override
  String pendingOsNotificationBody(int count) {
    return 'You have $count orders stalled for over 7 days.';
  }

  @override
  String get termsOfService => 'Terms and Conditions';

  @override
  String get termsOfServicePlaceholder =>
      'E.g.: Devices not picked up within 90 days may be discarded...';

  @override
  String get useDefaultTerms => 'Use default terms for this segment';

  @override
  String get pdfTermsAndConditions => 'Terms and Conditions';

  @override
  String get pdfCompanySignature => 'Responsible';

  @override
  String get pdfClientSignature => 'Client';

  @override
  String get pdfTechnician => 'Technician';

  @override
  String get pdfCreatedDate => 'Created';

  @override
  String get pdfCompletedDate => 'Completed';

  @override
  String get pdfIssuedDate => 'Issued';

  @override
  String get pdfServicesSubtotal => 'Services Subtotal';

  @override
  String get pdfPartsSubtotal => 'Parts Subtotal';

  @override
  String get pdfPaid => 'Paid';

  @override
  String get pdfUnitValue => 'Unit Price';

  @override
  String get pdfServiceType => 'Service';

  @override
  String get pdfProductType => 'Part';

  @override
  String get pdfItemType => 'Type';

  @override
  String get pdfSummary => 'Summary';

  @override
  String get pdfGeneral => 'General';

  @override
  String get pdfTrackOnline => 'Track online';

  @override
  String get pdfTrackOnlineDescription =>
      'Scan the QR Code to track this service order';

  @override
  String get pdfEquipment => 'Equipment';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get formTemplates => 'form templates';

  @override
  String featureGateNearLimit(int count, String feature) {
    return '$count $feature remaining';
  }

  @override
  String featureGateLimitReached(String feature) {
    return '$feature limit reached';
  }

  @override
  String featureGateUpgradeSuggestion(String plan) {
    return 'Upgrade to $plan for more';
  }

  @override
  String featureGateUsageInfo(int current, int limit) {
    return 'Used $current of $limit';
  }

  @override
  String get featureGateLimitModalTitle => 'Limit reached';

  @override
  String get subscription => 'Subscription';

  @override
  String get manageSubscription => 'Manage subscription';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get restorePurchasesSuccess => 'Purchases restored successfully';

  @override
  String get restorePurchasesError =>
      'Error restoring purchases. Please try again.';

  @override
  String get success => 'Success';

  @override
  String get free => 'Free';

  @override
  String renewsOn(String date) {
    return 'Renews on $date';
  }

  @override
  String get manageInStore => 'Manage in app store';

  @override
  String get restore => 'Restore';

  @override
  String get currentPlan => 'Current plan';

  @override
  String featureLimitReached(String feature) {
    return 'You\'ve reached the limit for $feature';
  }

  @override
  String get photoLimitReachedMessage =>
      'You have reached this month\'s photo limit.';

  @override
  String get photoLimitUpgradeHint => 'Upgrade to add more photos.';

  @override
  String get viewPlans => 'View plans';

  @override
  String get askAdminToChangePlanTitle => 'Talk to your admin';

  @override
  String get askAdminToChangePlan =>
      'Ask the account administrator to change the plan.';

  @override
  String get subscriptionUnavailable =>
      'Subscriptions are not available right now. Please try again later.';

  @override
  String planActiveMessage(String plan) {
    return 'Your $plan plan is active.';
  }

  @override
  String get restorePurchasesNothingFound =>
      'No active subscription was found for this store account.';

  @override
  String get planLimitUpgradeHint => 'Subscribe to a plan to raise this limit.';

  @override
  String get deleteAccountStoreSubscriptionWarning =>
      'Deleting your account does not cancel an App Store or Google Play subscription. Cancel it first in your store settings so you are not charged again.';

  @override
  String get asaasConnected => 'Connected';

  @override
  String get asaasDisconnected => 'Not connected';

  @override
  String get asaasConnectTitle => 'Connect Asaas account';

  @override
  String get asaasConnectStep1 =>
      '1. In the Asaas dashboard, open Integrations > API Keys.';

  @override
  String get asaasConnectStep2 => '2. Generate a new key and copy it.';

  @override
  String get asaasConnectStep3 => '3. Paste the key below and tap Connect.';

  @override
  String get asaasOpenPanel => 'Open Asaas dashboard';

  @override
  String get asaasOpenSandboxPanel => 'Open test dashboard (sandbox)';

  @override
  String get asaasApiKey => 'API key';

  @override
  String get asaasApiKeyPlaceholder => 'Paste the key here';

  @override
  String get asaasApiKeyHint =>
      'The key is stored encrypted on the server and is never shown in the app again.';

  @override
  String get asaasConnect => 'Connect';

  @override
  String get asaasAccount => 'Account';

  @override
  String get asaasEnvironment => 'Environment';

  @override
  String get asaasEnvironmentSandbox => 'Test';

  @override
  String get asaasEnvironmentProduction => 'Production';

  @override
  String get asaasDisconnect => 'Disconnect';

  @override
  String get asaasDisconnectConfirm =>
      'Disconnect the Asaas account? Open charges stay in Asaas, but payments will no longer update the order.';

  @override
  String get asaasErrorInvalidKey => 'Invalid API key. Check it and try again.';

  @override
  String get asaasErrorForbidden =>
      'You don\'t have permission for this action.';

  @override
  String get asaasErrorNotConnected =>
      'Connect the Asaas account in Settings > Integrations.';

  @override
  String get asaasErrorExceedsBalance =>
      'The amount is higher than the order balance.';

  @override
  String get asaasErrorTaxIdRequired => 'Enter the customer\'s CPF or CNPJ.';

  @override
  String get asaasErrorCustomerRequired =>
      'Add a customer to the order before charging.';

  @override
  String get asaasErrorGeneric => 'Could not complete. Please try again.';

  @override
  String get invalidTaxId => 'Invalid CPF or CNPJ';

  @override
  String get chargeValue => 'Amount';

  @override
  String chargeBalanceHint(String value) {
    return 'Order balance: $value';
  }

  @override
  String get chargeSingleHint => 'The customer chooses Pix, boleto or card.';

  @override
  String chargeInstallmentOption(int count, String value) {
    return '${count}x of $value';
  }

  @override
  String get chargeDueDate => 'Due date';

  @override
  String get chargeTaxIdHint =>
      'Asaas requires a CPF or CNPJ. It is saved to the customer record.';

  @override
  String get chargeStatusPending => 'Awaiting payment';

  @override
  String get chargeStatusOverdue => 'Overdue';

  @override
  String get chargeStatusPaid => 'Paid';

  @override
  String get chargeStatusCanceled => 'Canceled';

  @override
  String get chargeStatusRefunded => 'Refunded';

  @override
  String get chargeCancelConfirm =>
      'The customer will no longer be able to pay with this link.';

  @override
  String get chargeKeep => 'Keep';

  @override
  String get chargeReplaceTitle => 'There is already an open charge';

  @override
  String get chargeReplaceConfirm =>
      'Creating a new charge cancels the previous one in Asaas.';

  @override
  String get chargeReplace => 'Create new';

  @override
  String get asaasErrorInstallmentsInProgress =>
      'This installment plan already has paid installments. Wait for it to finish or refund in Asaas.';

  @override
  String get asaasErrorCustomerChargeOpen =>
      'This order is already in a payment link for several orders of the customer. Cancel that link in Receive from the customer.';

  @override
  String get asaasErrorChargeSuperseded =>
      'Another link for these orders was created at the same time and is the one that counts. See it on the order or the customer.';

  @override
  String get asaasErrorPreviousLinkCanceled =>
      'An old link was canceled, but the new one was not created. Send a new link.';

  @override
  String get asaasErrorOrderNotPayable =>
      'Quotes and canceled orders cannot be charged.';

  @override
  String get asaasErrorOrderCanceled =>
      'This order is canceled and cannot be charged.';

  @override
  String get asaasErrorInvalidDueDate =>
      'Invalid due date. Choose today or a future date.';

  @override
  String get asaasErrorInvalidInstallmentCount =>
      'Invalid number of installments. Choose from 2 to 12.';

  @override
  String get asaasErrorChargeNotOpen => 'This charge is no longer open.';

  @override
  String get asaasErrorValidation =>
      'Asaas rejected the charge data. Check the customer\'s CPF/CNPJ and email.';

  @override
  String get asaasErrorUnavailable =>
      'Asaas is unavailable right now. Please try again shortly.';

  @override
  String get listLoadError =>
      'Could not load this. Check your connection and try again.';

  @override
  String get pickCustomerTitle => 'Who is the customer?';

  @override
  String searchCustomerPlaceholder(String serial) {
    return 'Search by name, phone or $serial';
  }

  @override
  String get customerNamePlaceholder => 'E.g.: Ana Ribeiro';

  @override
  String get customerNameRequired => 'Enter the customer name';

  @override
  String get orderMissingWhatsapp => 'WhatsApp';

  @override
  String get customerPhoneLabel => 'Phone or WhatsApp';

  @override
  String get customerPhoneHint =>
      'Used to send the quote and the ready notice.';

  @override
  String get moreCustomerData => 'More details (email, tax ID, address)';

  @override
  String get openInMap => 'Open in maps';

  @override
  String get callAction => 'Call';

  @override
  String newOrderFor(String name) {
    return 'New order for $name';
  }

  @override
  String devicesOfCustomer(String devices, String name) {
    return '$name\'s $devices';
  }

  @override
  String get totalSpent => 'Total spent';

  @override
  String deleteCustomerTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteCustomerKeepsOrders => 'The orders stay saved.';

  @override
  String get deleteAction => 'Delete';

  @override
  String get noCustomersYet => 'You have no customers yet';

  @override
  String get addFirstCustomer => 'Add your first customer';

  @override
  String noCustomerMatching(String query) {
    return 'No customer matching “$query”';
  }

  @override
  String customersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count customers',
      one: '1 customer',
    );
    return '$_temp0';
  }

  @override
  String openOrdersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open orders',
      one: '1 open order',
    );
    return '$_temp0';
  }

  @override
  String lateOrdersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count late orders',
      one: '1 late order',
    );
    return '$_temp0';
  }

  @override
  String get customerActions => 'More customer actions';

  @override
  String get customerLookupError => 'Could not load customers. Try again.';

  @override
  String get catalogTitle => 'Catalog';

  @override
  String get catalogNewService => 'New service';

  @override
  String get catalogNewProduct => 'New product';

  @override
  String get saveServiceButton => 'Save service';

  @override
  String get saveProductButton => 'Save product';

  @override
  String serviceNameHint(String segment) {
    String _temp0 = intl.Intl.selectLogic(segment, {
      'automotive': 'Oil change',
      'hvac': 'Split AC cleaning',
      'smartphones': 'Screen replacement',
      'computers': 'OS reinstall',
      'appliances': 'Refrigerator repair',
      'electrical': 'Breaker replacement',
      'plumbing': 'Leak repair',
      'security': 'Camera installation',
      'solar': 'Panel cleaning',
      'printers': 'Toner replacement',
      'bicycles': 'Full tune-up',
      'software_it': 'Monthly IT support',
      'other': 'Maintenance',
    });
    return 'E.g.: $_temp0';
  }

  @override
  String productNameHint(String segment) {
    String _temp0 = intl.Intl.selectLogic(segment, {
      'automotive': 'Oil filter',
      'hvac': 'Capacitor',
      'smartphones': 'Screen',
      'computers': 'RAM memory',
      'appliances': 'Heating element',
      'electrical': 'Circuit breaker',
      'plumbing': 'Shutoff valve',
      'security': 'Camera',
      'solar': 'Inverter',
      'printers': 'Toner',
      'bicycles': 'Inner tube',
      'software_it': 'Microsoft 365 license',
      'other': 'Spare part',
    });
    return 'E.g.: $_temp0';
  }

  @override
  String get serviceNameRequired => 'Enter the service name';

  @override
  String get productNameRequired => 'Enter the product name';

  @override
  String get catalogPriceLabel => 'Price';

  @override
  String get catalogPriceHint =>
      'You can leave it blank and set the price on each order.';

  @override
  String get addServicePhoto => 'Service photo';

  @override
  String get addProductPhoto => 'Product photo';

  @override
  String get catalogNoPrice => 'no price';

  @override
  String get catalogEmptyServices => 'You don\'t have any services yet';

  @override
  String get catalogEmptyServicesHint =>
      'Add the ones you do most to build orders faster.';

  @override
  String get catalogEmptyProducts => 'You don\'t have any products yet';

  @override
  String get catalogEmptyProductsHint =>
      'Add the ones you use most to build orders faster.';

  @override
  String catalogNoMatch(String query) {
    return 'Nothing matching “$query”';
  }

  @override
  String catalogDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get catalogDeleteMessage =>
      'It leaves the catalog. Orders that already use it stay saved.';

  @override
  String get deleteServiceAction => 'Delete service';

  @override
  String get deleteProductAction => 'Delete product';

  @override
  String get catalogItemActions => 'More item actions';

  @override
  String get pickServiceTitle => 'Which service?';

  @override
  String get pickProductTitle => 'Which product?';

  @override
  String get catalogLoadError => 'Could not load the catalog. Try again.';

  @override
  String newEntity(String entity) {
    return 'New $entity';
  }

  @override
  String get photoAndMoreData => 'Photo and more details';

  @override
  String fieldRequiredHint(String field) {
    return 'Fill in the $field field';
  }

  @override
  String useValue(String value) {
    return 'Use “$value”';
  }

  @override
  String get newOrderAction => 'New order';

  @override
  String get deviceActions => 'More actions';

  @override
  String deleteDeviceTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteDeviceKeepsOrders => 'The orders stay saved.';

  @override
  String get deviceDetailsLabel => 'Details';

  @override
  String orderNewTitle(String order) {
    return 'New $order';
  }

  @override
  String orderNumberTitle(String order, String number) {
    return '$order $number';
  }

  @override
  String get orderItemsSection => 'What will be done';

  @override
  String orderItemSearchPlaceholder(String product) {
    return 'Search service or $product';
  }

  @override
  String get orderCreateItemError => 'Could not create it. Try again.';

  @override
  String get orderCatalogEmpty =>
      'Your catalog is empty. Type the name in the search to create one.';

  @override
  String get orderMostUsed => 'Most used';

  @override
  String get orderAllItems => 'All';

  @override
  String get orderItemKindService => 'service';

  @override
  String get orderItemKindProduct => 'product';

  @override
  String orderItemQuantityValue(String count) {
    return '$count units';
  }

  @override
  String get orderItemPrice => 'Price';

  @override
  String get orderItemPriceHint =>
      'You can leave it blank: the item has no price and stays out of the total.';

  @override
  String get orderItemDescription => 'Description';

  @override
  String get orderItemDescriptionHint =>
      'Optional: what is specific to this item, such as the part or the side. Shows on the order and the PDF.';

  @override
  String get orderItemQuantity => 'Quantity';

  @override
  String get orderItemLess => 'One less';

  @override
  String get orderItemMore => 'One more';

  @override
  String get orderItemRemove => 'Remove from the order';

  @override
  String get orderItemDiscard => 'Don\'t add';

  @override
  String get orderTotalLabel => 'Total';

  @override
  String orderRemainingToReceive(String amount) {
    return 'Left to receive $amount';
  }

  @override
  String get orderFullyPaid => 'Fully paid';

  @override
  String get orderSaveNeedsCustomer => 'Choose the customer to save.';

  @override
  String get orderDiscardTitle => 'Leave without saving?';

  @override
  String get orderDiscardMessage => 'What you filled in will be lost.';

  @override
  String get orderKeepEditing => 'Keep editing';

  @override
  String orderPickDevice(String device) {
    return 'Choose $device';
  }

  @override
  String get orderTalkAction => 'Say what to do';

  @override
  String orderNextStepReceive(String amount) {
    return 'Receive $amount';
  }

  @override
  String orderMenuAddTo(String order) {
    return 'Add to the $order';
  }

  @override
  String get orderMenuSendToCustomer => 'Send to the customer';

  @override
  String orderMenuCancel(String order) {
    return 'Cancel $order';
  }

  @override
  String orderMenuDelete(String order) {
    return 'Delete $order';
  }

  @override
  String get orderAddDueDate => 'Delivery date';

  @override
  String orderAddAnotherDevice(String device) {
    return 'Another $device';
  }

  @override
  String orderCancelConfirmTitle(String order) {
    return 'Cancel $order?';
  }

  @override
  String get orderCancelConfirmMessage =>
      'It goes to the canceled ones and can be reopened.';

  @override
  String orderDeleteConfirmTitle(String order) {
    return 'Delete $order?';
  }

  @override
  String get orderDeleteConfirmMessage => 'This cannot be undone.';

  @override
  String get orderPhotosSection => 'Photos';

  @override
  String orderUnpricedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items without price, out of the total',
      one: '1 item without price, out of the total',
    );
    return '$_temp0';
  }

  @override
  String orderPendingChecklists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count checklists are not finished',
      one: '1 checklist is not finished',
    );
    return '$_temp0';
  }

  @override
  String get orderMoreActions => 'More actions';

  @override
  String get filterOpen => 'Open';

  @override
  String get filterAll => 'All';

  @override
  String get filterMine => 'Mine';

  @override
  String get nextVisitLabel => 'Now';

  @override
  String homeWithYouToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count with you today',
      one: '1 with you today',
    );
    return '$_temp0';
  }

  @override
  String homeWithYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count with you',
      one: '1 with you',
    );
    return '$_temp0';
  }

  @override
  String nextVisit(String customer, String time) {
    return 'Next: $customer, at $time.';
  }

  @override
  String nextVisitDevice(String customer, String device, String time) {
    return 'Next: $customer, $device, at $time.';
  }

  @override
  String openOrderNumber(String number) {
    return 'Open order $number';
  }

  @override
  String get noOrdersWithYou => 'No orders with you.';

  @override
  String homeOpenCount(int count) {
    return '$count open';
  }

  @override
  String get seeAllOrders => 'See all';

  @override
  String notificationsA11y(int count) {
    return 'Notifications, $count new';
  }

  @override
  String get howItWorks => 'How it works';

  @override
  String get firstOrderLabel => 'Start here';

  @override
  String get homeNoOrdersYet => 'None yet';

  @override
  String get howItWorksStep1 => '1. Write down the job';

  @override
  String get howItWorksStep1Detail => 'customer and services';

  @override
  String howItWorksStep1DetailDevice(String device) {
    return 'customer, $device and services';
  }

  @override
  String get howItWorksStep2 => '2. Send the quote';

  @override
  String get howItWorksStep2Detail => 'over WhatsApp, with a link';

  @override
  String get howItWorksStep3 => '3. Get paid and deliver';

  @override
  String get howItWorksStep3Detail => 'the app reminds you who still owes';

  @override
  String get searchNotFoundLoaded => 'Not found in the loaded orders.';

  @override
  String get searchOlder => 'Search older ones';

  @override
  String get noOpenOrders => 'No open orders.';

  @override
  String get noOrdersInView => 'Nothing here.';

  @override
  String get loadOrdersError => 'Could not load the orders.';

  @override
  String orderLateMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Overdue $count months',
      one: 'Overdue 1 month',
    );
    return '$_temp0';
  }

  @override
  String orderLateYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Overdue $count years',
      one: 'Overdue 1 year',
    );
    return '$_temp0';
  }

  @override
  String orderLateDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Overdue $count days',
      one: 'Overdue 1 day',
    );
    return '$_temp0';
  }

  @override
  String orderStatusDue(String status, String date) {
    return '$status · due $date';
  }

  @override
  String orderRowNumber(String number) {
    return 'Order $number';
  }

  @override
  String get yourAccount => 'Your account';

  @override
  String get yourCompany => 'Details for customers';

  @override
  String get catalog => 'Catalog';

  @override
  String get planTitle => 'Plan';

  @override
  String get advancedTitle => 'Advanced';

  @override
  String get deleteMyAccount => 'Delete my account';

  @override
  String get howYouWork => 'How you work';

  @override
  String get valuesAndBilling => 'Prices and billing';

  @override
  String get valuesAndBillingHint =>
      'Prices on orders, receiving payments and the Financial tab';

  @override
  String get valuesAndBillingOffTitle => 'Turn off prices and billing?';

  @override
  String get valuesAndBillingOffMessage =>
      'Prices, totals, receiving payments and the Financial tab disappear for the whole team. Nothing is deleted: values come back if you turn it on again. Payment links already sent remain valid.';

  @override
  String get valuesAndBillingOffAction => 'Turn off';

  @override
  String get valuesAndBillingSaveError =>
      'Could not save. Check your connection and try again.';

  @override
  String get joinWithInviteCode => 'Join with an invite code';

  @override
  String get followsPhoneSettings =>
      'Language and appearance follow your iPhone settings.';

  @override
  String get invitePerson => 'Invite someone';

  @override
  String get inviteWhoLabel => 'Name (optional)';

  @override
  String get inviteWhoPlaceholder => 'E.g. Lucas Silva';

  @override
  String get inviteEmailLabel => 'Email';

  @override
  String get inviteEmailHint =>
      'They sign in with this email and the invite shows up on its own.';

  @override
  String get inviteWhatsAppLabel => 'WhatsApp (optional)';

  @override
  String get inviteRoleLabel => 'What they can do';

  @override
  String get inviteRoleQuestion => 'What can they do?';

  @override
  String get createInvite => 'Create invite';

  @override
  String get userWillReceiveInviteByWhatsAppHint =>
      'Then you send the code to this number or through another app.';

  @override
  String get financialLoadError => 'Could not load your finances.';

  @override
  String financialEmptyMonth(String month) {
    return 'No orders in $month.';
  }

  @override
  String get financialAlreadyPaid => 'Already paid';

  @override
  String financialEmptyReceived(String month) {
    return 'No payments in $month.';
  }

  @override
  String get financialReceivable => 'To receive';

  @override
  String get financialInProgress => 'In progress';

  @override
  String get financialSold => 'Sold';

  @override
  String get financialToday => 'Today';

  @override
  String get financialReceivableCompleted => 'Completed jobs';

  @override
  String get financialReceivableOpen => 'Open jobs';

  @override
  String get financialNextCharge => 'Next charge';

  @override
  String get financialAlreadyReceived => 'Already received';

  @override
  String financialNextChargeMessage(String name, String amount, String date) {
    return '$name owes $amount since $date';
  }

  @override
  String get financialSendCharge => 'Send charge';

  @override
  String financialReceivableSummary(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count customers',
      one: '1 customer',
    );
    return '$amount from $_temp0';
  }

  @override
  String financialInProgressSummary(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders',
      one: '1 order',
    );
    return '$amount in $_temp0';
  }

  @override
  String financialMonthAmount(String month, String amount) {
    return '$month · $amount';
  }

  @override
  String financialSince(String date) {
    return 'since $date';
  }

  @override
  String financialOrderDate(int number, String date) {
    return 'Order $number · $date';
  }

  @override
  String get financialEmptyReceivable => 'Nobody owes you anything.';

  @override
  String get financialEmptyInProgress =>
      'No orders in progress with a balance.';

  @override
  String get financialToReceive => 'To collect';

  @override
  String financialOrderSince(int number, String date) {
    return 'Order $number · since $date';
  }

  @override
  String get financialOtherPeriod => 'Other period';

  @override
  String get financialPreviousMonth => 'Previous month';

  @override
  String get financialNextMonth => 'Next month';

  @override
  String financialPickOrderTitle(String name) {
    return 'Open orders of $name';
  }

  @override
  String financialOrderOption(int number, String amount, String date) {
    return 'Order $number · $amount · since $date';
  }

  @override
  String get receiveTitle => 'Receive';

  @override
  String get receiveMissing => 'Left to receive';

  @override
  String get receiveAllDone => 'All received';

  @override
  String get receiveAttachReceipt => 'Attach receipt';

  @override
  String get receiveAlreadyReceived => 'Already received';

  @override
  String get receiveWithReceipt => 'with receipt';

  @override
  String get receiveNoReceipt => 'no receipt';

  @override
  String get receiveViaPix => 'Pix via link';

  @override
  String get receiveViaBoleto => 'Boleto via link';

  @override
  String get receiveViaCard => 'Card via link';

  @override
  String get receiveViaLink => 'Via link';

  @override
  String get receiveGiveDiscount => 'Give a discount';

  @override
  String get receiveUndoPayments => 'Undo payments';

  @override
  String receiveDiscountNewTotal(String from, String to) {
    return 'The total goes from $from to $to';
  }

  @override
  String get receiveViewReceipt => 'View receipt';

  @override
  String get receiveRemovePayment => 'Remove this payment';

  @override
  String receiveRecordedBy(String name, String date) {
    return 'Recorded by $name on $date';
  }

  @override
  String receiveRecordedAuto(String date) {
    return 'Recorded automatically by the app on $date';
  }

  @override
  String get receiveMoreOptions => 'More options';

  @override
  String get receiveRemoveReceipt => 'Remove receipt';

  @override
  String get receiveWhen => 'When';

  @override
  String get receiveMarkReceived => 'Mark as received';

  @override
  String receiveReceivedFrom(String customer) {
    return 'Received from $customer';
  }

  @override
  String get receiveReceivedTitle => 'Received';

  @override
  String receiveSummaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'To receive · $count orders',
      one: 'To receive · 1 order',
    );
    return '$_temp0';
  }

  @override
  String receiveSummarySome(int checked, int total) {
    return 'To receive · $checked of $total orders';
  }

  @override
  String receiveSummaryOrder(String order) {
    return 'To receive · $order';
  }

  @override
  String get receiveSummaryPlain => 'To receive';

  @override
  String get receiveOrdersIncluded => 'Orders included';

  @override
  String receivePreviewAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Settles the $count orders.',
      one: 'Settles the order.',
    );
    return '$_temp0';
  }

  @override
  String receivePreviewSettles(String numbers) {
    return 'Settles orders $numbers.';
  }

  @override
  String receivePreviewPart(String amount, String number) {
    return 'Pays $amount of order $number.';
  }

  @override
  String receivePreviewLeft(String amount) {
    return '$amount left.';
  }

  @override
  String receiveChargeAdjusts(String customer) {
    return 'The open charge adjusts itself, without notifying $customer.';
  }

  @override
  String get receiveChargeAdjustsNoName =>
      'The open charge adjusts itself, without notifying the customer.';

  @override
  String get chargeSend => 'Send charge';

  @override
  String get chargeSendAgain => 'Send again';

  @override
  String get chargeSendOrderLink => 'Send order link';

  @override
  String chargeDetailUntil(String value, String date) {
    return 'Charge of $value · valid until $date';
  }

  @override
  String chargeDetailOverdue(String value) {
    return 'Charge of $value · can still be paid';
  }

  @override
  String chargeDetailValue(String value) {
    return 'Charge of $value';
  }

  @override
  String get receiveConfirmButton => 'Confirm payment';

  @override
  String receiveCustomerOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open orders. Check the ones that were paid.',
      one: '1 open order.',
    );
    return '$_temp0';
  }

  @override
  String get receiveCustomerPartHint =>
      'If you got only part of it, type how much.';

  @override
  String get receiveCustomerPaying => 'Paying for';

  @override
  String receiveCustomerOrderRow(int number, String description) {
    return 'Order $number · $description';
  }

  @override
  String get receiveCustomerRowSettles => 'Pays it off';

  @override
  String receiveCustomerRowPartial(String amount, String left) {
    return 'Gets $amount · $left left';
  }

  @override
  String get receiveCustomerRowLater => 'Left for later';

  @override
  String get receiveCustomerNoneChecked => 'Check at least one order.';

  @override
  String get receiveCustomerSendLink => 'Send payment link…';

  @override
  String receiveCustomerOpenOrder(int number) {
    return 'Open order $number';
  }

  @override
  String get receiveAttach => 'Attach';

  @override
  String receiveCustomerTitle(String name) {
    return 'Receive from $name';
  }

  @override
  String get receiveCustomerAmountLabel => 'How much you got';

  @override
  String get receiveCustomerOldestFirst =>
      'If the amount doesn\'t cover everything, the oldest are paid first.';

  @override
  String get receiveCustomerZero => 'Type how much you got.';

  @override
  String get receiveCustomerBalanceChanged =>
      'The amounts changed since this screen opened. Check them and confirm again.';

  @override
  String receiveCustomerDone(String amount, String name) {
    return 'Got $amount from $name';
  }

  @override
  String get receiveCustomerUploadFailed =>
      'Could not send the receipt. Check the internet and try again.';

  @override
  String receiveCustomerChargeIntro(String name, int count, String numbers) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'orders $numbers',
      one: 'order $numbers',
    );
    return '$name gets one link to pay $_temp0 by Pix, boleto or card.';
  }

  @override
  String receiveCustomerChargeOwedHint(String value) {
    return 'Open on these orders: $value';
  }

  @override
  String receiveCustomerOpenCharge(String amount) {
    return 'Open link for $amount';
  }

  @override
  String receiveCustomerOpenChargeDetail(String numbers, String date) {
    return 'Orders $numbers · due $date';
  }

  @override
  String get receiveCustomerShareCharge => 'Send the link again';

  @override
  String receiveCustomerChargeCancelTitle(String amount) {
    return 'Cancel the $amount link?';
  }

  @override
  String get receiveCustomerChargeCanceled => 'Link canceled';

  @override
  String receiveCustomerOthersTitle(String name) {
    return 'Other orders of $name';
  }

  @override
  String get receiveCustomerOthersNote =>
      'Created by someone else. Check one to include it; saving needs internet.';

  @override
  String get receiveCustomerOffline =>
      'No internet. To receive on someone else\'s orders you need to be online.';

  @override
  String receiveCustomerPickRow(int number) {
    return 'Order $number';
  }

  @override
  String receiveCustomerTooMuchChosen(String total) {
    return 'That is more than is open on these orders ($total).';
  }

  @override
  String get receiptTitle => 'Payment';

  @override
  String receiptRowSettled(int number, String amount) {
    return 'Order $number · $amount · paid off';
  }

  @override
  String receiptRowOpen(int number, String amount, String left) {
    return 'Order $number · $amount · $left open';
  }

  @override
  String receiptSendTo(String name) {
    return 'Send receipt to $name';
  }

  @override
  String get receiptSend => 'Send receipt';

  @override
  String get receiptActions => 'More payment options';

  @override
  String get receiptUndo => 'Undo payment';

  @override
  String receiptUndoTitle(String amount) {
    return 'Undo the payment of $amount?';
  }

  @override
  String receiptUndoMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders',
      one: '1 order',
    );
    return 'The amount comes off $_temp0 and is open again.';
  }

  @override
  String get receiptUndone => 'Payment undone';

  @override
  String get receiptCanceled => 'This payment was undone.';

  @override
  String get receiptPartOfGroup =>
      'This payment is part of a payment for several orders. To undo it, open the payment.';

  @override
  String get receiptOpen => 'Open payment';

  @override
  String get receiptsSection => 'Payments';

  @override
  String receiptListSubtitle(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders',
      one: '1 order',
    );
    return '$date · $_temp0';
  }

  @override
  String get receiptNotFound => 'We could not find this payment.';

  @override
  String get pdfReceiptTitle => 'Receipt';

  @override
  String pdfReceiptNumber(String number) {
    return 'No. $number';
  }

  @override
  String pdfReceiptSentence(String name, String amount, String date) {
    return 'We received from $name the amount of $amount on $date.';
  }

  @override
  String get pdfReceiptOrderColumn => 'Order';

  @override
  String get pdfReceiptPaidColumn => 'Paid now';

  @override
  String get pdfReceiptOpenColumn => 'Still open';

  @override
  String get pdfReceiptDescriptionColumn => 'Description';

  @override
  String get pdfReceiptTotal => 'Total received';

  @override
  String pdfReceiptRemaining(String amount) {
    return '$amount is still open on these orders.';
  }

  @override
  String pdfReceiptRecordedBy(String name) {
    return 'Recorded by $name';
  }

  @override
  String pdfReceiptFileName(String number) {
    return 'Receipt-$number';
  }

  @override
  String get loginTitle => 'You talk.\nPraticOS';

  @override
  String get loginTitleHighlight => 'writes the order.';

  @override
  String get loginTradeAutomotivo => 'Auto Repair Shop';

  @override
  String get loginTradeRefrigeracao => 'HVAC Technician';

  @override
  String get loginTradeEletrica => 'Electrician';

  @override
  String get loginTradeAssistenciaCelular => 'Phone Repair Shop';

  @override
  String get loginTradeHidraulica => 'Plumbing';

  @override
  String get loginTradeEnergiaSolar => 'Solar Installer';

  @override
  String get loginTradeInformatica => 'IT Services';

  @override
  String get loginTradeLimpeza => 'Cleaning Services';

  @override
  String get loginTradeEletronica => 'Electronics Repair';

  @override
  String get loginTradeSegurancaCftv => 'CCTV & Security';

  @override
  String get loginTradeBicicletaria => 'Bike Shop';

  @override
  String get loginTradeEletrodomesticos => 'Appliance Repair';

  @override
  String get loginTradeImpressoras => 'Printers';

  @override
  String get loginTradeAutomacao => 'Home Automation';

  @override
  String get loginTradeDedetizacao => 'Pest Control';

  @override
  String get loginTradeElevadores => 'Elevator Maintenance';

  @override
  String get loginTradeManutencaoPredial => 'Building Maintenance';

  @override
  String get loginTradeMoveis => 'Furniture Assembly';

  @override
  String get loginTradeManutencaoAtivos => 'Asset Maintenance';

  @override
  String get loginTradeObrasPublicas => 'Public Works';

  @override
  String get loginSampleSaid => 'You say';

  @override
  String get loginSampleAutomotivo =>
      '“Julia\'s Civic, oil change and alignment”';

  @override
  String get loginSampleRefrigeracao =>
      '“Martha\'s AC, cleaning and refrigerant recharge”';

  @override
  String get loginSampleEletrica =>
      '“Paul\'s house, new breakers in the panel”';

  @override
  String get loginSampleAssistenciaCelular =>
      '“Luke\'s iPhone, new screen and battery”';

  @override
  String get loginSampleHidraulica =>
      '“Anna\'s apartment, leak at the sink trap”';

  @override
  String get loginSampleEnergiaSolar => '“Charles\'s roof, two more panels”';

  @override
  String get loginSampleInformatica =>
      '“Bea\'s laptop, clean install and new SSD”';

  @override
  String get loginSampleLimpeza => '“Clara\'s office, window cleaning”';

  @override
  String get loginSampleEletronica => '“Joe\'s TV, new main board”';

  @override
  String get loginSampleSegurancaCftv =>
      '“Mark\'s store, four cameras installed”';

  @override
  String get loginSampleBicicletaria =>
      '“Peter\'s bike, full tune-up and new tire”';

  @override
  String get loginSampleEletrodomesticos => '“Sonia\'s washer, new water pump”';

  @override
  String get loginSampleImpressoras => '“Office printer, new fuser”';

  @override
  String get loginSampleAutomacao =>
      '“Renata\'s house, living room panel install”';

  @override
  String get loginSampleDedetizacao =>
      '“Tom\'s kitchen, pest control and report”';

  @override
  String get loginSampleElevadores =>
      '“Aurora Building, monthly elevator service”';

  @override
  String get loginSampleManutencaoPredial =>
      '“Garden Condo, hallway and lobby inspection”';

  @override
  String get loginSampleMoveis =>
      '“Lucy\'s wardrobe, assembly and adjustments”';

  @override
  String get loginSampleManutencaoAtivos => '“Line 2 motor, new bearings”';

  @override
  String get loginSampleObrasPublicas =>
      '“Flower Street, resurfacing of section 3”';

  @override
  String get loginSampleDone => 'Order ready to send';

  @override
  String get loginWithEmailLink => 'I already have an account with email';

  @override
  String get errorSignInAppleFriendly =>
      'Could not sign in with Apple. Please try again.';

  @override
  String get errorSignInGoogleFriendly =>
      'Could not sign in with Google. Please try again.';

  @override
  String get forgotPasswordQuestion => 'Forgot your password?';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get onboardingSegmentTitle => 'Your trade';

  @override
  String get onboardingInviteCode => 'I got an invite code';

  @override
  String get onboardingSegmentsError =>
      'Couldn\'t load the trades. Check your connection.';

  @override
  String get onboardingSpecialtiesTitle => 'Specialties';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingBusinessTitle => 'For your customers';

  @override
  String get onboardingBusinessName => 'Name shown on orders';

  @override
  String get onboardingBusinessNamePlaceholder =>
      'E.g. Joe\'s Repair or your own name';

  @override
  String get onboardingBusinessNameRequired =>
      'Enter the name shown on orders.';

  @override
  String get onboardingPhoneLabel => 'Phone (optional)';

  @override
  String get onboardingPhoneHint => 'Shown on the quotes your customers get.';

  @override
  String get onboardingSamplesInfo =>
      'We\'ll add a few sample orders so you can see how it works. Delete them anytime.';

  @override
  String get onboardingCreate => 'Create my PraticOS';

  @override
  String get onboardingStartWithoutSamples => 'Start without samples';

  @override
  String get onboardingPreparing => 'Setting up your PraticOS…';

  @override
  String get onboardingCreateError =>
      'Couldn\'t finish. Check your connection and try again.';

  @override
  String get receivedWhichOrder => 'Which order?';

  @override
  String receivedPhotosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String receivedPdfsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDFs',
      one: '1 PDF',
    );
    return '$_temp0';
  }

  @override
  String receivedSummaryBoth(String photos, String pdfs) {
    return '$photos and $pdfs';
  }

  @override
  String receivedSavedInOrder(String number, String summary) {
    return 'Saved to order $number · $summary';
  }

  @override
  String get receivedSaveFailed => 'Could not save. Try again.';

  @override
  String get receivedOpenOrder => 'Open the order';

  @override
  String get sharedFileQuestion => 'What is this file?';

  @override
  String sharedFileReceiptOf(String amount, String date) {
    return 'Receipt for the $amount payment · $date';
  }

  @override
  String get sharedFileNewPayment => 'Receipt for a new payment';

  @override
  String get sharedFileJustKeep => 'Just keep it in the order';

  @override
  String sharedFileReceiptSaved(String number) {
    return 'Receipt saved in order $number';
  }

  @override
  String get inviteGenericError =>
      'Could not finish. Check your internet and try again.';

  @override
  String get inviteLoadError =>
      'Could not load the invites. Check your internet.';

  @override
  String inviteTitleOne(String company) {
    return '$company invited you to the team';
  }

  @override
  String inviteInvitedByAs(String name, String role) {
    return 'Invited by $name · you join as $role';
  }

  @override
  String inviteEntersAs(String role) {
    return 'You join as $role';
  }

  @override
  String get inviteJoinTeam => 'Join the team';

  @override
  String get inviteDecline => 'Decline invite';

  @override
  String get inviteHaveAnotherCode => 'I have another code';

  @override
  String get inviteCreateOwnCompany => 'Start without an invite';

  @override
  String get inviteCodePlaceholder => 'E.g. 7K2P9QXA';

  @override
  String get segmentLoadError =>
      'Could not open your orders. Check your internet and try again.';

  @override
  String get orderAssistantAddPhoto => 'Take another photo';

  @override
  String get orderAssistantTakePhoto => 'Take a photo';

  @override
  String orderAssistantCustomerGuess(String name) {
    return 'I heard “$name”. Tap to choose the customer';
  }

  @override
  String orderAssistantDeviceGuess(String device) {
    return '“$device” is not registered';
  }

  @override
  String get orderAssistantErrorDisabled =>
      'The assistant is not available for your account yet.';

  @override
  String get orderAssistantErrorQuota =>
      'The assistant reached this month\'s limit. You can keep filling it in by hand.';

  @override
  String get orderAssistantErrorQuotaDay =>
      'The assistant reached today\'s limit. It\'s back tomorrow; you can keep filling it in by hand.';

  @override
  String get orderAssistantErrorUnavailable =>
      'Couldn\'t read it now. Try again or fill it in by hand.';

  @override
  String get orderAssistantNothingFound =>
      'I found nothing to add. Try again or fill it in by hand.';

  @override
  String get reportPreviousPeriod => 'Previous period';

  @override
  String get reportNextPeriod => 'Next period';

  @override
  String get orderAddChecklist => 'Checklist';

  @override
  String get orderAddComment => 'Comment';

  @override
  String get orderAddAddress => 'Service address';

  @override
  String get orderAddSchedule => 'Schedule date and time';

  @override
  String get orderAddDiscount => 'Discount';

  @override
  String orderChecklistMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions left',
      one: '1 question left',
    );
    return '$_temp0';
  }

  @override
  String get orderAddressChange => 'Change address';

  @override
  String get orderAddressRemove => 'Remove address';

  @override
  String get orderScheduleRemove => 'Remove schedule';

  @override
  String orderContractSummary(String frequency, String date) {
    return '$frequency · next on $date';
  }

  @override
  String get orderUploading => 'Uploading…';

  @override
  String otherDevicesSection(String devices) {
    return 'Other $devices';
  }

  @override
  String accumulatedDeleteConfirm(String value) {
    return 'Delete “$value”?';
  }

  @override
  String accumulatedUse(String value) {
    return 'Use “$value”';
  }

  @override
  String get accumulatedLeaveBlank => 'Leave blank';

  @override
  String get moreSectionCompany => 'Your work';

  @override
  String get moreSectionRecords => 'Records';

  @override
  String get moreSectionYou => 'You';

  @override
  String get moreCompanySubtitle => 'Order details, business type and features';

  @override
  String moreCatalogSubtitle(String products) {
    return 'Services and $products';
  }

  @override
  String planHeaderRenews(String plan, String date) {
    return '$plan · renews on $date';
  }

  @override
  String planHeaderValidUntil(String plan, String date) {
    return '$plan · valid until $date';
  }

  @override
  String planHeaderCourtesy(String plan, String date) {
    return '$plan · free until $date';
  }

  @override
  String planHeaderPaymentIssue(String plan) {
    return '$plan · payment problem';
  }

  @override
  String get planLimitLabel => 'Plan limit';

  @override
  String planLimitTeam(String used, String limit) {
    return 'Your team already has $used of $limit people. To invite someone else, change your plan.';
  }

  @override
  String planLimitPhotos(String used, String limit) {
    return 'You\'ve used $used of $limit photos this month. To take more, change your plan.';
  }

  @override
  String planLimitChecklists(String used, String limit) {
    return 'You already have $used of $limit checklists. To create another, change your plan.';
  }

  @override
  String get planUsageSection => 'What you\'re using';

  @override
  String get planUsageTeam => 'People on the team';

  @override
  String get planUsagePhotos => 'Photos this month';

  @override
  String get planUsageChecklists => 'Checklists';

  @override
  String planUsageOf(String used, String limit) {
    return '$used of $limit';
  }

  @override
  String get planUsageAtLimit => 'At the limit';

  @override
  String get planUsageAtLimitInvites => 'At the limit · invites count';

  @override
  String get planUsageNearLimit => 'Almost at the limit';

  @override
  String get planUsageUnlimited => 'No limit';

  @override
  String get companyShownOnOrder => 'Shown on the customer\'s order';

  @override
  String get companyNameLogoContact => 'Name, logo and contact';

  @override
  String get customerTerms => 'Terms for the customer';

  @override
  String get customerTermsHint => 'Warranty and conditions';

  @override
  String get segmentRow => 'Line of business';

  @override
  String get segmentRowHint => 'Changes the ready-made services and checklists';

  @override
  String get moreCompanyData => 'More details (email, website, country)';

  @override
  String get addLogo => 'Add logo';

  @override
  String get changeLogoLink => 'Change logo';

  @override
  String get pickSegmentTitle => 'What\'s your line of work?';

  @override
  String get pickSpecialtiesTitle => 'What do you work on?';

  @override
  String get specialtiesNone => 'None selected';

  @override
  String get pickCountryTitle => 'Which country?';

  @override
  String get companyNameRequired => 'Enter the name shown on orders';

  @override
  String get schedulingRow => 'Schedule';

  @override
  String get schedulingRowHint => 'Set the day and time of orders';

  @override
  String get fieldServiceRow => 'Service at the customer\'s place';

  @override
  String get fieldServiceRowHint => 'Customer address on the order';

  @override
  String get contractsRowHint => 'Orders that repeat by themselves';

  @override
  String deviceControlRow(String devices) {
    return '$devices tracking';
  }

  @override
  String get deviceControlRowHint => 'History and full list';

  @override
  String get companySettingSaveError =>
      'Couldn\'t save. Check your connection and try again.';

  @override
  String customerSpentValue(String value) {
    return 'spent $value';
  }

  @override
  String customerOwesValue(String value) {
    return 'Owes $value';
  }

  @override
  String customerInProgressValue(String value) {
    return 'In progress $value';
  }

  @override
  String askOrderForCustomer(String name) {
    return 'Open a work order for $name?';
  }

  @override
  String askOrderForDevice(String device) {
    return 'Open a work order for this $device?';
  }

  @override
  String addAnotherDevice(String device) {
    return 'Add another $device';
  }

  @override
  String get latestOrders => 'Latest work orders';

  @override
  String ordersOfDevice(String device) {
    return 'Work orders of this $device';
  }

  @override
  String orderCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count WO',
      one: '1 WO',
    );
    return '$_temp0';
  }

  @override
  String get deviceOwnerPrefix => 'owner: ';

  @override
  String get financialReportShort => 'Report';

  @override
  String get financialSendReportPdf => 'Send report as PDF';

  @override
  String receiveSubtitle(String customer, String total) {
    return '$customer · total $total';
  }

  @override
  String receiveSubtitleNoCustomer(String total) {
    return 'total $total';
  }

  @override
  String receiveOrderLink(int number) {
    return 'Order $number';
  }

  @override
  String get receiveAmountHint =>
      'Got only part of it? Tap the amount and type how much.';

  @override
  String get orderAddContractMonthly => 'Repeat every month (contract)';

  @override
  String get ratingsSubtitle => 'What customers thought';

  @override
  String get ratingsLatest => 'Latest';

  @override
  String ratingScoreOf(String score) {
    return '$score of 5';
  }

  @override
  String ratingsAverageOf(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ratings',
      one: 'rating',
    );
    return 'average of $count $_temp0';
  }

  @override
  String ratingCommentOrder(String comment, int number) {
    return '“$comment” · Order $number';
  }

  @override
  String ratingNoCommentOrder(int number) {
    return 'No comment · Order $number';
  }

  @override
  String get remindersSubtitle => 'They only apply on this phone';

  @override
  String get reminderBeforeTitle => 'Before the scheduled time';

  @override
  String get reminderDailyTitle => 'Daily summary at 9am';

  @override
  String get reminderDailySubtitle => 'What is on for today';

  @override
  String get reminderPendingTitle => 'Stalled orders';

  @override
  String get reminderPendingSubtitle => 'Quotes with no answer for 7 days';

  @override
  String get reminderInactivityTitle => 'If I go days without opening the app';

  @override
  String reminderMinutesValue(int minutes) {
    return '$minutes min';
  }

  @override
  String reminderHoursValue(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'hours',
      one: 'hour',
    );
    return '$hours $_temp0';
  }

  @override
  String get catalogSubtitle => 'What you put on your orders';

  @override
  String catalogKindWithCount(String kind, int count) {
    return '$kind ($count)';
  }

  @override
  String get catalogTip =>
      'Tip: you can add items right on the order by typing the name in the search.';

  @override
  String get teamTitle => 'Team';

  @override
  String teamSummary(String people, String invites) {
    return '$people and $invites';
  }

  @override
  String teamPeopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String teamInvitesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invites',
      one: '1 invite',
    );
    return '$_temp0';
  }

  @override
  String get teamInviteWaitingLabel => 'Invite waiting';

  @override
  String teamInviteWaitingText(String name, String expiry) {
    return '$name hasn\'t joined yet. $expiry';
  }

  @override
  String teamInviteExpiresInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The invite expires in $count days.',
      one: 'The invite expires in 1 day.',
    );
    return '$_temp0';
  }

  @override
  String get teamInviteExpiresToday => 'The invite expires today.';

  @override
  String get teamInviteExpired => 'The invite has expired.';

  @override
  String get teamResendInvite => 'Resend invite';

  @override
  String get teamWaitingSection => 'Waiting to join';

  @override
  String get teamMembersSection => 'On the team';

  @override
  String teamInviteSent(String expiry) {
    return 'Invite sent · $expiry';
  }

  @override
  String teamInviteDueInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'expires in $count days',
      one: 'expires in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get teamInviteDueToday => 'expires today';

  @override
  String get teamInviteDueExpired => 'expired';

  @override
  String teamYou(String name) {
    return '$name (you)';
  }

  @override
  String get teamInviteAnother => 'Invite someone else';

  @override
  String get teamInviteFirst => 'Invite someone';

  @override
  String get roleShortAdmin => 'sees and changes everything';

  @override
  String get roleShortSupervisor => 'coordinates the team, doesn\'t see prices';

  @override
  String get roleShortManager => 'sees revenue and costs';

  @override
  String get roleShortConsultant => 'makes quotes, sees only their orders';

  @override
  String get roleShortTechnician => 'does the work, doesn\'t see prices';

  @override
  String get checklistsTitle => 'Checklists';

  @override
  String get checklistsSubtitle =>
      'Questions the technician answers on the order';

  @override
  String get checklistsYours => 'Your checklists';

  @override
  String get checklistsReady => 'Ready to use';

  @override
  String checklistQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
    );
    return '$_temp0';
  }

  @override
  String get checklistWithPhotos => 'with photos';

  @override
  String get checklistOff => 'Off';

  @override
  String get checklistUse => 'Use';

  @override
  String get checklistNew => 'New checklist';

  @override
  String get checklistsEmpty =>
      'No checklists yet. Create one or use a ready-made one.';

  @override
  String get noticesTitle => 'Notices';

  @override
  String noticesNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new',
      one: '1 new',
    );
    return '$_temp0';
  }

  @override
  String get noticesMarkAllRead => 'Mark all as read';

  @override
  String get noticesSectionNew => 'New';

  @override
  String get noticesSectionBefore => 'Earlier';

  @override
  String get noticesEmpty => 'No notices yet.';

  @override
  String get timeAgoNow => 'now';

  @override
  String timeAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String contractsSubtitle(String order) {
    return '$order that repeat on their own';
  }

  @override
  String get contractsTabActive => 'Active';

  @override
  String get contractsTabEnded => 'Ended';

  @override
  String contractEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String contractEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String contractEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String contractEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count years',
      one: 'Every year',
    );
    return '$_temp0';
  }

  @override
  String contractNextOrderOn(String date, String order) {
    return 'Next $order on $date';
  }

  @override
  String contractEndedOn(String date) {
    return 'Ended on $date';
  }

  @override
  String get contractEnded => 'Ended';

  @override
  String get contractsEmptyEnded => 'No ended contracts.';

  @override
  String contractsFooterHint(String order) {
    return 'Contracts start inside a $order: turn on “Repeat this $order”.';
  }

  @override
  String get orderAddResponsible => 'Responsible';

  @override
  String get orderResponsibleRemove => 'Remove responsible';

  @override
  String get filterDone => 'Completed';

  @override
  String homeLateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count late',
      one: '1 late',
    );
    return '$_temp0';
  }

  @override
  String get homeSearchHint => 'Search orders or customers';

  @override
  String homeSearchHintDevice(String device) {
    return 'Search orders, customers or $device';
  }

  @override
  String remainingToReceive(String amount) {
    return '$amount left to receive';
  }

  @override
  String remainingShort(String amount) {
    return '$amount left';
  }

  @override
  String get firstOrderTapPlus =>
      'Tap + to create your first work order. It takes less than a minute.';

  @override
  String profileButtonA11y(String company) {
    return '$company: catalog, team and settings';
  }

  @override
  String get orderAssistantPhoto => 'Photo';

  @override
  String get orderAssistantTalkShort => 'Speak';

  @override
  String get orderCustomerRequestTitle => 'What the customer asked';

  @override
  String orderCustomerRequestPlaceholder(String segment) {
    String _temp0 = intl.Intl.selectLogic(segment, {
      'automotive': 'noise when braking',
      'hvac': 'not cooling',
      'smartphones': 'cracked screen',
      'computers': 'won\'t turn on',
      'appliances': 'stopped working',
      'electrical': 'outlet with no power',
      'plumbing': 'leak under the sink',
      'security': 'camera with no image',
      'solar': 'low generation',
      'printers': 'paper jam',
      'bicycles': 'chain skipping',
      'software_it': 'report won\'t open',
      'other': 'not working',
    });
    return 'E.g.: $_temp0';
  }

  @override
  String get orderDeliverySection => 'Delivery';

  @override
  String get orderDueLabel => 'Ready by';

  @override
  String get orderDueNone => 'No date';

  @override
  String get orderMoreOptions => 'More options';

  @override
  String get orderMoreOptionsHint => 'Status, visit, assignee, location';

  @override
  String get orderStatusLabel => 'Status';

  @override
  String get orderScheduleLabel => 'Visit';

  @override
  String get orderAddressLabel => 'Location';

  @override
  String speechHint(String device) {
    return 'Say the customer, the $device and what will be done.';
  }

  @override
  String get speechListening => 'Listening…';

  @override
  String get speechFill => 'Fill in the order';

  @override
  String get speechUnavailable =>
      'The microphone is not allowed. Allow it in Settings or type the job.';

  @override
  String orderAddItemRow(String product) {
    return 'Add service or $product';
  }

  @override
  String get orderPickCustomerRow => 'Choose customer';

  @override
  String get newOrderButton => 'New order';

  @override
  String get orderAssistantFilled =>
      'I filled in what\'s marked. Check it and save.';

  @override
  String get orderAssistantUndo => 'Undo';

  @override
  String orderNotifyNote(String status, String name) {
    return '$status. Let $name know?';
  }

  @override
  String get orderNotifyFallbackName => 'the customer';

  @override
  String get orderNotifyAction => 'Let know';

  @override
  String get orderAssistantReadingPhotos => 'Reading the photos…';

  @override
  String get orderAssistantReadingSpeech => 'Reading what you said…';

  @override
  String get orderAssistantMarked => 'Filled in by AI';

  @override
  String get speechCancel => 'Cancel';

  @override
  String get speechStopAndFill => 'Stop and fill in the order';

  @override
  String speechTypeHint(String device) {
    return 'Type the customer, the $device and what will be done';
  }

  @override
  String get speechNothingHeard =>
      'I didn\'t hear anything. Tap Speak and try again.';

  @override
  String get orderServicesAndParts => 'Services and parts';

  @override
  String get orderItemKindPart => 'part';

  @override
  String get orderActionApproveQuote => 'Approve quote';

  @override
  String get orderActionStartService => 'Start the job';

  @override
  String get orderActionMarkReady => 'Mark as ready';

  @override
  String orderDuePhrase(String when) {
    return 'Ready $when';
  }

  @override
  String orderDueLatePhrase(String when) {
    return 'Was due $when';
  }

  @override
  String orderDayAtTime(String day, String time) {
    return '$day at $time';
  }

  @override
  String orderChecklistProgress(int answered, int total) {
    return '$answered of $total answered';
  }

  @override
  String get orderCommentYou => 'You';

  @override
  String get orderMenuChangeStatus => 'Change status';

  @override
  String get orderMenuViewPdf => 'View PDF';

  @override
  String get orderMenuCopyLink => 'Copy link';

  @override
  String get orderPlaceOfService => 'Service location';

  @override
  String get orderAssistantApplied =>
      'I added what\'s marked to the order. Check it.';

  @override
  String orderAssistantWhichLine(String name) {
    return 'Which $name?';
  }

  @override
  String get orderAssistantChanged =>
      'I changed the order as you asked. Check it.';

  @override
  String orderAssistantWhichCustomer(String name) {
    return 'Which $name?';
  }

  @override
  String orderAssistantRegisterNewCustomer(String name) {
    return 'Add $name as a new customer';
  }

  @override
  String get orderAssistantOtherCustomer => 'Another customer';

  @override
  String get orderAssistantNewCustomer => 'new';

  @override
  String orderAssistantWhichDevice(String name) {
    return 'Which $name?';
  }

  @override
  String orderAssistantRegisterNewDevice(String name) {
    return 'Add $name';
  }

  @override
  String orderAssistantOtherDevice(String label) {
    return 'Another $label';
  }

  @override
  String get orderAssistantNewDevice => 'new';

  @override
  String get pickerCustomerTitle => 'Which customer?';

  @override
  String pickerDeviceTitle(String device) {
    return 'Which $device?';
  }

  @override
  String pickerDeviceSubtitle(String name) {
    return 'for $name';
  }

  @override
  String get pickerItemTitle => 'What will be done?';

  @override
  String get pickerChecklistTitle => 'Which checklist?';

  @override
  String get pickerStatusTitle => 'What is the status?';

  @override
  String get pickerAssigneeTitle => 'Who is responsible?';

  @override
  String pickerDevicesTitle(String devices) {
    return 'On which $devices?';
  }

  @override
  String get pickerNewCustomer => 'New customer';

  @override
  String pickerNewDevice(String device) {
    return 'New $device';
  }

  @override
  String pickerNewItem(String product) {
    return 'New service or $product';
  }

  @override
  String get pickerNewChecklist => 'New checklist';

  @override
  String pickerRegister(String query) {
    return 'Add “$query”';
  }

  @override
  String pickerNoDeviceWith(String device, String query) {
    return 'No $device matching “$query”.';
  }

  @override
  String pickerNoItemWith(String product, String query) {
    return 'No service or $product matching “$query”. Add it and it goes straight on the order.';
  }

  @override
  String pickerNoMatch(String query) {
    return 'Nothing matching “$query”.';
  }

  @override
  String get pickerRecent => 'Recent';

  @override
  String get pickerAll => 'All';

  @override
  String get pickerSearch => 'Search';

  @override
  String pickerNoDevice(String device) {
    return 'No $device';
  }

  @override
  String get formMoreData => 'More details';

  @override
  String get customerSaveNeedsName => 'Type the name to save.';

  @override
  String get pickFromContacts => 'Choose from contacts';

  @override
  String get contactWhichNumber => 'Which number?';

  @override
  String get customerDuplicateTitle => 'Already registered';

  @override
  String customerDuplicateMessage(String name) {
    return '$name already has this phone number.';
  }

  @override
  String get customerDuplicateOpen => 'Open customer';

  @override
  String get customerDuplicateSaveAnyway => 'Save anyway';

  @override
  String get contactReadFailed => 'Couldn\'t read this contact.';

  @override
  String contactFirstOfMany(int count) {
    return 'This file has $count contacts. We opened the first one.';
  }

  @override
  String get contactCannotAddCustomer => 'Your profile can\'t add customers.';

  @override
  String get customerMoreDataHint => 'E-mail, tax ID, address';

  @override
  String deviceMoreDataHint(String brand, String category) {
    return 'Photo, $brand and $category';
  }

  @override
  String get catalogMoreDataHintFields => 'Photo and other fields';

  @override
  String get inviteSaveNeedsContact => 'Type the e-mail or WhatsApp to save.';

  @override
  String get checklistNamePlaceholder => 'E.g.: Check-in inspection';

  @override
  String get checklistQuestionsTitle => 'Questions';

  @override
  String get checklistAddQuestion => 'Add question';

  @override
  String get checklistSaveNeedsNameAndQuestion =>
      'Type the name and add a question to save.';

  @override
  String get checklistSaveNeedsQuestion => 'Add a question to save.';

  @override
  String get checklistNameLabel => 'Checklist name';

  @override
  String get checklistSave => 'Save checklist';

  @override
  String get checklistSaveError => 'Couldn\'t save the checklist. Try again.';

  @override
  String get checklistStopUsing => 'Stop using';

  @override
  String get checklistUseAgain => 'Use again';

  @override
  String get checklistDelete => 'Delete checklist';

  @override
  String get checklistDeleteTitle => 'Delete this checklist?';

  @override
  String checklistDeleteMessage(String name) {
    return '“$name” leaves the list and no longer shows up in new orders.';
  }

  @override
  String get checklistQuestionNew => 'New question';

  @override
  String get checklistQuestion => 'Question';

  @override
  String checklistQuestionPlaceholder(String segment) {
    String _temp0 = intl.Intl.selectLogic(segment, {
      'automotive': 'Are the tires OK?',
      'hvac': 'Is the drain clear?',
      'smartphones': 'Does the screen turn on?',
      'computers': 'Is the fan spinning?',
      'appliances': 'Does it turn on?',
      'electrical': 'Is the panel labeled?',
      'plumbing': 'Any sign of a leak?',
      'security': 'Are the cameras recording?',
      'solar': 'Are the panels clean?',
      'printers': 'Is the print sharp?',
      'bicycles': 'Are the brakes OK?',
      'software_it': 'Did the backup run?',
      'other': 'Is it working?',
    });
    return 'E.g.: $_temp0';
  }

  @override
  String get checklistAnswerType => 'Type of answer';

  @override
  String get checklistOptions => 'Options';

  @override
  String get checklistOptionsPlaceholder => 'E.g.: Good\nFair\nBad';

  @override
  String get checklistQuestionRequiredHint => 'Can\'t finish without an answer';

  @override
  String get checklistQuestionAllowPhotos => 'Can add a photo';

  @override
  String get checklistQuestionDelete => 'Delete question';

  @override
  String get checklistQuestionNeedsLabel => 'Write the question to continue.';

  @override
  String get checklistQuestionNeedsOptions =>
      'Write at least 2 options, one per line.';

  @override
  String get checklistQuestionRequiredShort => 'required';

  @override
  String get checklistQuestionWithPhoto => 'with photo';

  @override
  String get formItemTypeText => 'Text';

  @override
  String get formItemTypeNumber => 'Number';

  @override
  String get formItemTypeBoolean => 'Yes or no';

  @override
  String get formItemTypeSelect => 'Pick one option';

  @override
  String get formItemTypeChecklist => 'Pick several options';

  @override
  String get formItemTypePhoto => 'Photo only';

  @override
  String get pickerNewItemKind => 'What are you adding?';

  @override
  String get pickerNewItemServiceHint => 'Work you do';

  @override
  String get pickerNewItemProductHint => 'Part or material you sell';

  @override
  String receiveSubtitleWithDiscount(
    String customer,
    String total,
    String discount,
  ) {
    return '$customer · total $total · discount $discount';
  }

  @override
  String receiveSubtitleNoCustomerWithDiscount(String total, String discount) {
    return 'total $total · discount $discount';
  }

  @override
  String chargeSendLinkTo(String customer) {
    return 'Send $customer a link to pay';
  }

  @override
  String get chargeSendLink => 'Send a link to pay';

  @override
  String chargeLinkSentOn(String date) {
    return 'Link sent on $date';
  }

  @override
  String get chargeLinkSent => 'Link sent';

  @override
  String chargeLinkExpiredOn(String date) {
    return 'The link expired on $date';
  }

  @override
  String chargeNotPaidYet(String customer, String value) {
    return '$customer hasn\'t paid the $value yet.';
  }

  @override
  String chargeNotPaidYetNoCustomer(String value) {
    return 'The $value hasn\'t been paid yet.';
  }

  @override
  String chargeLinkValidUntil(String date) {
    return 'The link is valid until $date.';
  }

  @override
  String get chargeRemindWhatsApp => 'Also remind on WhatsApp';

  @override
  String get chargeReceivedOtherWay => 'I got paid another way';

  @override
  String get chargeLinkSection => 'Payment link';

  @override
  String get chargePaymentLink => 'Payment link';

  @override
  String chargeWaitingFor(String customer) {
    return 'Waiting for $customer to pay';
  }

  @override
  String get chargeWaitingPayment => 'Waiting for payment';

  @override
  String chargeExpiredOn(String date) {
    return 'Expired on $date';
  }

  @override
  String chargeMethodsUntil(String date) {
    return 'Pix, boleto or card · until $date';
  }

  @override
  String chargeInstallmentsUntil(int count, String date) {
    return '${count}x on card · until $date';
  }

  @override
  String chargeInstallmentsPaid(int paid, int count) {
    return '$paid of $count installments paid';
  }

  @override
  String chargeUntilReplaced(String date) {
    return 'until $date · the new link cancels this one';
  }

  @override
  String get chargeOrderChanged => 'The order total changed';

  @override
  String chargeNowMissing(String remaining, String value) {
    return 'Now $remaining is due, but the link still charges $value.';
  }

  @override
  String chargeGenerateNew(String value) {
    return 'Create a new $value link';
  }

  @override
  String chargeKeepLink(String value) {
    return 'Keep the $value link';
  }

  @override
  String get chargeSendAgainWhatsApp => 'Send again on WhatsApp';

  @override
  String get chargeCopyLink => 'Copy link';

  @override
  String get chargeLinkCopied => 'Link copied';

  @override
  String get chargeCancelLink => 'Cancel charge';

  @override
  String get chargeLinkTitle => 'Send charge';

  @override
  String chargeLinkIntro(String name) {
    return '$name gets the link and pays by Pix, boleto or card.';
  }

  @override
  String get chargeLinkIntroNoName =>
      'The customer gets the link and pays by Pix, boleto or card.';

  @override
  String get chargeSplitQuestion => 'Split on the card?';

  @override
  String get chargeSplitOnCard => 'Split on the card';

  @override
  String get chargeSplitNo => 'No';

  @override
  String get profileEditTitle => 'Your profile';

  @override
  String get profileChangePhoto => 'Change photo';

  @override
  String profileSignedInAs(String email) {
    return 'You sign in with $email';
  }

  @override
  String get profileNameRequired => 'Type your name';

  @override
  String get profileNamePlaceholder => 'E.g. John Smith';

  @override
  String get financialWhichOrder => 'Which order?';

  @override
  String get reportThisWeek => 'This week';

  @override
  String get reportThisMonth => 'This month';

  @override
  String get reportThisYear => 'This year';

  @override
  String get reportPickDates => 'Pick dates';

  @override
  String get reportSeeOtherPeriod => 'See another period';

  @override
  String get reportStarts => 'Starts';

  @override
  String get reportEnds => 'Ends';

  @override
  String get reportWhichPeriod => 'Which period?';

  @override
  String get agendaShowMonth => 'Show month';

  @override
  String get agendaShowWeek => 'Show week';

  @override
  String agendaWhose(String name) {
    return 'Whose: $name';
  }

  @override
  String get agendaWhoseTitle => 'Whose to show?';

  @override
  String agendaOnlyOf(String name) {
    return 'Only $name';
  }

  @override
  String get agendaShowAll => 'Show all';

  @override
  String agendaWithPerson(String name) {
    return 'with $name';
  }

  @override
  String agendaDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scheduled',
      one: '1 scheduled',
    );
    return '$_temp0';
  }

  @override
  String agendaDayHasOrders(String day) {
    return '$day, has scheduled work';
  }

  @override
  String get agendaPreviousWeek => 'Previous week';

  @override
  String get agendaNextWeek => 'Next week';

  @override
  String get agendaPreviousMonth => 'Previous month';

  @override
  String get agendaNextMonth => 'Next month';

  @override
  String noticeCommented(String name, String text) {
    return '$name commented: “$text”';
  }

  @override
  String noticePaymentReceived(String amount) {
    return 'Payment of $amount received';
  }

  @override
  String get contractNew => 'New contract';

  @override
  String get orderRepeatRow => 'Repeat';

  @override
  String contractsEmptyAdd(String order) {
    return 'Tap + to create a $order that repeats on its own.';
  }

  @override
  String get contractRepeats => 'Repeats';

  @override
  String get contractRepeatsTitle => 'How often?';

  @override
  String get contractStarts => 'Starts';

  @override
  String get contractEnds => 'Ends';

  @override
  String get contractNeverEnds => 'Never';

  @override
  String get contractNoEndDate => 'No end date';

  @override
  String contractAutoCreate(String order) {
    return 'Create the $order on its own';
  }

  @override
  String contractAutoCreateHint(String order) {
    return 'On, the new $order shows up by itself on the date. Off, you only get the reminder.';
  }

  @override
  String get contractRemind => 'Remind me';

  @override
  String get contractRemindTitle => 'How early should we remind you?';

  @override
  String contractRemindDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days before',
      one: '1 day before',
      zero: 'On the day',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSegmentHint =>
      'The app comes ready with the services and checklists of your trade.';

  @override
  String get onboardingSpecialtiesHint =>
      'Check what fits. You can change it later.';

  @override
  String get emailLoginTitle => 'Sign in with email';

  @override
  String get emailLoginNewAccountHint =>
      'No account yet? Go back and continue with Apple or Google.';

  @override
  String get emailLoginEmailRequired => 'Enter your email.';

  @override
  String get emailLoginEmailInvalid =>
      'That email doesn\'t look right. Please check it.';

  @override
  String get emailLoginPasswordRequired => 'Enter your password.';

  @override
  String get emailLoginWrongCredentials =>
      'Email or password doesn\'t match. Check them and try again.';

  @override
  String get emailLoginNoInternet =>
      'No internet. Check your connection and try again.';

  @override
  String get emailLoginTooManyAttempts =>
      'Too many tries. Wait a bit and try again.';

  @override
  String get emailLoginGenericError => 'Couldn\'t sign in. Try again.';

  @override
  String get emailLoginSigningIn => 'Signing in…';

  @override
  String get resetPasswordTitle => 'Reset your password';

  @override
  String get resetPasswordMessage => 'We\'ll send a link to your email.';

  @override
  String get resetPasswordError =>
      'Couldn\'t send the email. Check the address and try again.';

  @override
  String get inviteTitleMany => 'You\'ve been invited';

  @override
  String get inviteManyHint => 'Tap an invite to see it and join the team.';

  @override
  String get inviteCodeTitle => 'What\'s the invite code?';

  @override
  String checklistRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count left',
      one: '1 left',
      zero: 'All answered',
    );
    return '$_temp0';
  }

  @override
  String get checklistQuestionNext => 'Next';

  @override
  String get checklistQuestionDone => 'Done';

  @override
  String get checklistSkipForNow => 'Skip for now';

  @override
  String get checklistPreviousQuestion => 'Back to the previous one';

  @override
  String get checklistPreviousShort => 'Previous';

  @override
  String get checklistSkipShort => 'Skip';

  @override
  String get checklistQuestionRequired => 'Required';

  @override
  String get checklistPickFromGallery => 'Choose from library';

  @override
  String get checklistTextPlaceholder => 'Type here';

  @override
  String get checklistStart => 'Start';

  @override
  String get checklistFinish => 'Finish checklist';

  @override
  String get checklistFinishAnyway => 'Finish anyway';

  @override
  String get checklistStatusDone => 'Complete';

  @override
  String get checklistNoAnswer => 'No answer';

  @override
  String checklistPhotoPosition(int current, int total) {
    return '$current of $total';
  }

  @override
  String get shareTitle => 'Send to the customer';

  @override
  String shareCanAll(String name, String order) {
    return '$name opens the $order from the link, approves and comments.';
  }

  @override
  String shareCanApprove(String name, String order) {
    return '$name opens the $order from the link and approves.';
  }

  @override
  String shareCanComment(String name, String order) {
    return '$name opens the $order from the link and comments.';
  }

  @override
  String shareCanView(String name, String order) {
    return '$name opens the $order from the link.';
  }

  @override
  String get shareTheCustomer => 'The customer';

  @override
  String shareValidUntil(String date) {
    return 'Valid until $date.';
  }

  @override
  String get shareSendWhatsApp => 'Send on WhatsApp';

  @override
  String get shareSendLink => 'Send the link';

  @override
  String get shareSendOtherWay => 'Send another way';

  @override
  String get shareCopyLink => 'Copy the link';

  @override
  String get shareSendPdf => 'Send the PDF';

  @override
  String get sharePreparingPdf => 'Preparing the PDF…';

  @override
  String get shareSendLinkWhatsApp => 'Send just the link on WhatsApp';

  @override
  String get shareSendLinkOnly => 'Send just the link';

  @override
  String get shareLinkCopied => 'Link copied';

  @override
  String get sharePreparing => 'Getting the link ready…';

  @override
  String get shareError => 'Couldn\'t create the link.';

  @override
  String get shareValidity => 'Change how long it lasts';

  @override
  String get shareValidityTitle => 'How long should it last?';

  @override
  String shareValidityDays(int count) {
    return '$count days';
  }

  @override
  String get sharePermissionsTitle => 'What can the customer do?';

  @override
  String get sharePermAll => 'View, approve and comment';

  @override
  String get sharePermApprove => 'View and approve';

  @override
  String get sharePermComment => 'View and comment';

  @override
  String get sharePermView => 'View only';

  @override
  String get shareNewLink => 'Make a new link';

  @override
  String get shareRevoke => 'Turn off the link';

  @override
  String shareRevokeConfirm(String order) {
    return 'The customer won\'t be able to open the $order from this link anymore.';
  }

  @override
  String get shareMenu => 'Link options';

  @override
  String get orderItemNotesPlaceholder => 'Anything else about this item';

  @override
  String get orderItemRemoveTitle => 'Remove from the order?';

  @override
  String orderItemRemoveMessage(String name) {
    return '\"$name\" leaves the order and its total.';
  }

  @override
  String get orderItemQuantityInvalid => 'Enter at least 1.';

  @override
  String orderPhotoShareText(String order) {
    return 'Photo of the $order';
  }

  @override
  String get orderPhotoShareError => 'Could not share the photo. Try again.';

  @override
  String get orderPhotoDeleteTitle => 'Delete this photo?';

  @override
  String get orderPhotoDeleted => 'Photo deleted';

  @override
  String get orderPhotoDeleteError => 'Could not delete the photo. Try again.';

  @override
  String get orderPhotoCoverSet => 'Photo set as cover';

  @override
  String get orderDocumentTypeTitle => 'What document is this?';

  @override
  String get shareWhatCanDo => 'What the customer can do';

  @override
  String get orderPhotoDelete => 'Delete photo';

  @override
  String get contractStopRepeating => 'Stop repeating';

  @override
  String get contractStopRepeatingTitle => 'Stop repeating?';

  @override
  String get contractStopRepeatingMessage =>
      'No new orders will be created. Existing ones stay.';

  @override
  String get commentsEmpty => 'No comments yet.';

  @override
  String get commentsTeamOnly => 'Team only';

  @override
  String get commentsCustomerSees =>
      'The customer also sees it, on the order link';

  @override
  String get commentsCustomerHidden => 'The customer doesn\'t see it';

  @override
  String get commentTeamOnlyTag => 'team only';

  @override
  String get commentSendError => 'Couldn\'t send. Try again.';

  @override
  String get inviteSheetTitle => 'Team invite';

  @override
  String inviteShareSentence(int days) {
    return 'Send this code so the person can join the team. It works for $days days.';
  }

  @override
  String get inviteShareButton => 'Share invite';

  @override
  String get inviteSendWhatsApp => 'Send on WhatsApp';

  @override
  String get inviteCopyCode => 'Copy code';

  @override
  String get inviteMenu => 'More invite options';

  @override
  String get teamCancelInvite => 'Cancel invite';

  @override
  String teamCancelInviteQuestion(String name) {
    return 'Cancel $name\'s invite?';
  }

  @override
  String get teamCancelInviteMessage => 'The code will stop working.';

  @override
  String get teamKeepInvite => 'Keep invite';

  @override
  String get teamInviteCanceled => 'Invite canceled';

  @override
  String teamInviteExpiredQuestion(String name) {
    return '$name\'s invite expired';
  }

  @override
  String get teamInviteExpiredMessage =>
      'The code no longer works. Invite again to send a new code.';

  @override
  String get teamInviteAgain => 'Invite again';

  @override
  String teamMemberRoleQuestion(String name) {
    return 'What can $name do?';
  }

  @override
  String get teamRemoveMember => 'Remove from team';

  @override
  String teamRemoveMemberQuestion(String name) {
    return 'Remove $name from the team?';
  }

  @override
  String get teamRemoveMemberMessage => 'They lose access to the orders.';

  @override
  String get teamRoleChanged => 'Role changed';

  @override
  String teamMemberRemoved(String name) {
    return '$name was removed from the team';
  }

  @override
  String get integrationsAiSection => 'ChatGPT and Claude';

  @override
  String get integrationsEmptyLine =>
      'No connections yet. Tap + to link PraticOS to ChatGPT or Claude.';

  @override
  String get integrationsRevoked => 'Connection revoked';

  @override
  String get asaasConnectHeadline =>
      'Connect your Asaas account to get paid by Pix, boleto and card through the order.';

  @override
  String get asaasConnectedHeadline =>
      'Asaas payments settle the order on their own.';

  @override
  String get asaasConnecting => 'Connecting…';

  @override
  String get asaasConnectedToast => 'Asaas account connected';

  @override
  String get asaasDisconnectedToast => 'Asaas account disconnected';

  @override
  String get asaasMenu => 'More Asaas options';

  @override
  String get nfseErrorAsaasValidation =>
      'Asaas rejected the invoice data. Check the customer\'s tax ID and address and the tax setup.';

  @override
  String get nfseErrorNotEnabled =>
      'Service invoices are not turned on for this company.';

  @override
  String get nfseErrorNotReady =>
      'The service invoice setup is not finished. See Integrations, Asaas.';

  @override
  String get nfseErrorOrderNotAllowed =>
      'This order can\'t have an invoice: it is a quote or was canceled.';

  @override
  String get nfseErrorNoServices =>
      'This order has no priced service. Only services go into the invoice.';

  @override
  String get nfseErrorOrderHasInvoice =>
      'This order already has an invoice. Cancel it before issuing another.';

  @override
  String get nfseErrorOrderNotOfCustomer =>
      'Every order in the invoice must be of the same customer.';

  @override
  String get nfseErrorNotFound =>
      'We couldn\'t find this invoice. Refresh the screen.';

  @override
  String get nfseErrorNotCancelable => 'This invoice can\'t be canceled now.';

  @override
  String get nfseErrorCancelNotSupported =>
      'This city doesn\'t allow canceling the invoice from here. Cancel it on the city\'s website.';

  @override
  String get nfseErrorInvalidDate => 'The invoice date can\'t be before today.';

  @override
  String get nfseErrorInvalidFiscalInfo =>
      'Asaas didn\'t accept the tax details. Check them with your accountant.';

  @override
  String get nfseErrorReconnectNeeded => 'Reconnect Asaas to issue invoices.';

  @override
  String get nfseErrorSetupNeeded =>
      'The Asaas account changed. Set up the service invoice again.';

  @override
  String get nfseErrorOtherAccount =>
      'This invoice belongs to another Asaas account. Cancel it there.';

  @override
  String get nfseConflictNotice =>
      'Invoice issued outside PraticOS, check it in Asaas.';

  @override
  String get nfseStatusWaiting => 'Waiting for the city';

  @override
  String nfseStatusScheduledFor(String date) {
    return 'Will be issued on $date';
  }

  @override
  String get nfseStatusIssued => 'Issued';

  @override
  String nfseStatusIssuedNumber(String number) {
    return 'Issued · no. $number';
  }

  @override
  String get nfseStatusIssuedAuto => 'Issued automatically';

  @override
  String nfseStatusIssuedAutoNumber(String number) {
    return 'Issued automatically · no. $number';
  }

  @override
  String get nfseAutoMissingTaxId => 'The customer\'s tax ID is missing';

  @override
  String get nfseAutoCertificateExpired => 'Certificate expired';

  @override
  String get nfseAutoEmitterNotReady => 'The invoice CNPJ needs setup';

  @override
  String get nfseAutoDailyLimit => 'Today\'s invoice limit';

  @override
  String get nfseAutoNotIssued => 'Not issued automatically';

  @override
  String get nfseAutoErrorPickEmitter =>
      'Choose the default CNPJ in Invoice so invoices go out automatically.';

  @override
  String get nfseStatusCanceling => 'Canceling';

  @override
  String get nfseStatusCancelDenied => 'Cancellation refused';

  @override
  String get nfseStatusCanceled => 'Canceled';

  @override
  String get nfseStatusError => 'Refused by the city';

  @override
  String get nfseListTitle => 'Service invoices';

  @override
  String nfseListCustomerTitle(String name) {
    return 'Invoices for $name';
  }

  @override
  String nfseListSummary(int count, String month, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invoices went out in $month, for a total of $value.',
      one: '1 invoice went out in $month, for $value.',
      zero: 'No invoices went out in $month.',
    );
    return '$_temp0';
  }

  @override
  String nfseListEmpty(String month) {
    return 'No invoices in $month';
  }

  @override
  String get nfseListEmptyHint => 'To issue one, open the order and tap “…”.';

  @override
  String get nfseListEmptyHintDirect =>
      'To issue one, open the order and tap “Service invoice”.';

  @override
  String get nfseListSearch => 'Customer, invoice or order number';

  @override
  String get nfseListAttention => 'Needs attention';

  @override
  String nfseListAttentionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count need attention',
      one: '1 needs attention',
    );
    return '$_temp0';
  }

  @override
  String nfseListNumber(String number) {
    return 'Invoice $number';
  }

  @override
  String nfseListOrders(String numbers) {
    return 'Order $numbers';
  }

  @override
  String get nfseListOnlyServices =>
      'Only services go on the invoice, so the total may differ from Sold.';

  @override
  String nfseListNoResults(String month) {
    return 'Nothing found in $month.';
  }

  @override
  String get nfseListMenu => 'More invoice options';

  @override
  String get nfseListSetup => 'Set up invoices';

  @override
  String get nfseNotIssued => 'Not issued';

  @override
  String get nfseIssueLink => 'Issue';

  @override
  String get nfseFixAndIssue => 'Fix and issue';

  @override
  String get nfseSharePdf => 'Share PDF';

  @override
  String get nfseRowTitle => 'Service invoice';

  @override
  String get nfseCompanyRowNoCnpj => 'Add your CNPJ to start';

  @override
  String get nfseCompanyRowPending => 'Setup not finished';

  @override
  String get nfseCompanyRowReady => 'Ready to issue';

  @override
  String get nfseIssueAction => 'Issue service invoice';

  @override
  String get nfseIssueSeveralAction => 'Issue one invoice for several orders';

  @override
  String get nfseValueLabel => 'Invoice amount';

  @override
  String get nfseOnlyServicesNote =>
      'Only services go into the invoice. Parts and products stay out.';

  @override
  String get nfseDiscountNote =>
      'The discount was split between services and parts.';

  @override
  String nfseOrderLine(String number, String value) {
    return 'Order $number · $value';
  }

  @override
  String get nfseDescriptionLabel => 'What the invoice says';

  @override
  String get nfseDateLabel => 'Invoice date';

  @override
  String get nfseServiceRow => 'City service';

  @override
  String get nfseTaxIdHint =>
      'The invoice needs the customer\'s tax ID. It is saved on their record.';

  @override
  String get nfseTaxIdMissing => 'The customer\'s tax ID is missing';

  @override
  String get nfseErrorCustomerData =>
      'The city needs the customer\'s email and full address (with ZIP code). Fill them in and issue again.';

  @override
  String nfseErrorAsaasSaid(String detail) {
    return 'Asaas refused the invoice: $detail';
  }

  @override
  String get nfseErrorSetupRejected =>
      'Asaas refused the invoice setup (service or tax data). Check it in Set up.';

  @override
  String get nfseCustomerDataIntro =>
      'The city needs the customer\'s email and address. They are saved on the customer.';

  @override
  String get nfseCustomerDataMissing =>
      'The customer\'s email or address is missing';

  @override
  String get nfsePostalCode => 'ZIP code';

  @override
  String get nfseStreet => 'Street';

  @override
  String get nfseAddressComplement => 'Apt, suite';

  @override
  String get nfseDistrict => 'District';

  @override
  String get nfseHeadNotIssued =>
      'The invoice did not go out. Fix the reason below and issue it again.';

  @override
  String get nfseNothingToIssue =>
      'Nothing to issue: the invoice would have no amount';

  @override
  String nfseAlreadyIssued(String numbers) {
    return 'Order $numbers already has an invoice';
  }

  @override
  String get nfseSent => 'Invoice sent to the city';

  @override
  String nfseSeveralIntro(int count, String name, String numbers) {
    return 'One invoice for $count orders of $name: $numbers.';
  }

  @override
  String get nfseNotReadyTitle => 'Service invoices aren\'t set up yet';

  @override
  String get nfseNotReadyAdmin =>
      'Before the first invoice, fill in the company\'s tax details and the invoice service.';

  @override
  String get nfseNotReadyOther =>
      'Ask the company owner to set up service invoices in Integrations, Asaas.';

  @override
  String get nfseSetupAction => 'Set up';

  @override
  String get nfsePickOrdersTitle => 'Which orders go into the invoice?';

  @override
  String nfsePickOrderSubtitle(String value, String date) {
    return 'Services $value · $date';
  }

  @override
  String get nfseNoOrdersToPick =>
      'No order of this customer can have an invoice now';

  @override
  String get nfseHeadWaiting => 'The city is still reviewing the invoice.';

  @override
  String nfseHeadScheduled(String date) {
    return 'The invoice goes to the city on $date.';
  }

  @override
  String get nfseHeadIssued => 'The invoice was issued.';

  @override
  String get nfseHeadError =>
      'The city refused the invoice. Check the tax details and the customer record, then issue it again.';

  @override
  String get nfseHeadCanceling => 'The city is canceling the invoice.';

  @override
  String get nfseHeadCancelDenied =>
      'The city refused to cancel the invoice. It is still valid.';

  @override
  String get nfseHeadCanceled => 'The invoice was canceled.';

  @override
  String get nfseReasonLabel => 'Reason given by the city';

  @override
  String get nfseNumberLabel => 'Number';

  @override
  String get nfseOrdersLabel => 'Orders in the invoice';

  @override
  String get nfseOpenPdf => 'Open invoice PDF';

  @override
  String get nfseOpenXml => 'Open invoice XML';

  @override
  String get nfseMenu => 'More invoice options';

  @override
  String get nfseCancelAction => 'Cancel invoice';

  @override
  String nfseCancelQuestion(String value) {
    return 'Cancel the $value invoice?';
  }

  @override
  String get nfseCancelMessage =>
      'The city gets the request and the invoice stops being valid. The order\'s payment stays as it is.';

  @override
  String get nfseKeep => 'Keep invoice';

  @override
  String get nfseCancelRequested => 'Cancellation request sent';

  @override
  String get nfseCancelAtCityTitle => 'Cancel on the city\'s website';

  @override
  String get nfseCancelAtCityMessage =>
      'This city doesn\'t allow canceling the invoice from here. Cancel it on its website, then mark it here.';

  @override
  String get nfseCanceledAtCity => 'I already canceled it at the city';

  @override
  String get nfseCanceledToast => 'Invoice canceled';

  @override
  String get nfseSetupReady => 'Ready to issue';

  @override
  String get nfseSetupMissingShort => 'Not set up yet';

  @override
  String get nfseSetupHeadReady =>
      'All set. Issue the invoice from the order\'s “…”.';

  @override
  String nfseSetupHeadMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps left before issuing invoices.',
      one: '1 step left before issuing invoices.',
    );
    return '$_temp0';
  }

  @override
  String get nfseSetupFiscalInfo => 'Company tax details';

  @override
  String get nfseSetupCityAccess => 'City access';

  @override
  String get nfseSetupService => 'Invoice service';

  @override
  String get nfseSetupDone => 'Done';

  @override
  String get nfseSetupTodo => 'Missing';

  @override
  String get nfseSetupNext => 'Set up what\'s missing';

  @override
  String get nfseCityAccessCertificate =>
      'The city asks for the company\'s digital certificate. Send it in the Asaas dashboard, under Invoices.';

  @override
  String get nfseCityAccessPassword =>
      'The city asks for the login of its website. Enter it in the Asaas dashboard, under Invoices.';

  @override
  String get nfseCityAccessToken =>
      'The city asks for an access code. Enter it in the Asaas dashboard, under Invoices.';

  @override
  String get nfseCityAccessFirst =>
      'Fill in the tax details first: then we know what the city asks for.';

  @override
  String get nfseCityAccessNone => 'This city doesn\'t ask for extra access.';

  @override
  String get nfseOpenAsaasPanel => 'Open the Asaas dashboard';

  @override
  String get nfseCheckAgain => 'I sent it, check again';

  @override
  String get nfseNoCancelNote =>
      'This city doesn\'t allow canceling from the app: cancel on its website.';

  @override
  String get nfseFiscalNote =>
      'These details stay in Asaas and go on every invoice. If unsure, ask your accountant.';

  @override
  String get nfseFiscalEmail => 'Email that receives the invoices';

  @override
  String get nfseFiscalMunicipalInscription => 'Municipal registration';

  @override
  String get nfseFiscalSimples => 'Simples Nacional company';

  @override
  String get nfseFiscalCnae => 'CNAE (if your accountant asks)';

  @override
  String get nfseFiscalSpecialRegime => 'Special tax regime';

  @override
  String get nfseFiscalSpecialRegimeQuestion => 'Which special tax regime?';

  @override
  String get nfseFiscalServiceListItem => 'Service list item';

  @override
  String get nfseFiscalEmailMissing => 'Type a valid email to save.';

  @override
  String get nfseFiscalSaved => 'Tax details saved';

  @override
  String get nfseServicePickTitle => 'Which service do you provide?';

  @override
  String get nfseServiceSearch => 'Search by name, e.g. maintenance';

  @override
  String get nfseServiceSearchEmpty =>
      'Nothing found. Try another word or type the code.';

  @override
  String get nfseServiceTypeCode => 'Type the code';

  @override
  String get nfseServiceCode => 'Service code at the city';

  @override
  String get nfseServiceName => 'Service name';

  @override
  String get nfseServiceMissing => 'Pick the city service to save.';

  @override
  String get nfseIss => 'ISS (%)';

  @override
  String get nfseRetainIss => 'The customer withholds the ISS';

  @override
  String get nfseOtherTaxes => 'Other taxes (%)';

  @override
  String get nfseTaxesNote =>
      'Use what the city and your accountant say. Leave 0 where it doesn\'t apply.';

  @override
  String get nfseTemplateLabel => 'Invoice text';

  @override
  String nfseTemplateHint(Object os, Object servicos) {
    return '$servicos becomes the order\'s services and $os the order numbers.';
  }

  @override
  String get nfseServiceSaved => 'Invoice service saved';

  @override
  String get nfseAutoIssueRow => 'Issue the invoice';

  @override
  String get nfseAutoIssueQuestion => 'When to issue the invoice?';

  @override
  String get nfseAutoIssueManual => 'Only when I ask';

  @override
  String get nfseAutoIssuePaid => 'When the order is paid';

  @override
  String get nfseAutoIssueCompleted => 'When the order is completed';

  @override
  String get nfseAutoIssueManualHint =>
      'You issue it from the order or customer menu.';

  @override
  String get nfseAutoIssuePaidHint =>
      'Goes out by itself when the customer finishes paying the order.';

  @override
  String get nfseAutoIssueCompletedHint =>
      'Goes out by itself when the order is completed, before payment.';

  @override
  String get nfseHeadAutoError =>
      'The invoice did not go out by itself. Fix the reason below and issue it.';

  @override
  String get nfseAutoReasonLabel => 'Why it did not go out';

  @override
  String get nfseAutoErrorTaxId => 'The customer has no tax ID on file.';

  @override
  String recurringOrdersTitle(String orders) {
    return 'Recurring $orders';
  }

  @override
  String get customerSaveError => 'Couldn\'t save the customer. Try again.';

  @override
  String chargeMissingOutsideLink(String value) {
    return '$value more is missing outside the link.';
  }

  @override
  String get chargeInstallmentsCanceled => 'Installment plan canceled';

  @override
  String chargeSendNewLink(String value) {
    return 'Send a new link for $value.';
  }

  @override
  String orderAssistantUsesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count assistant uses left this month.',
      one: '1 assistant use left this month.',
      zero: 'No assistant uses left this month.',
    );
    return '$_temp0';
  }

  @override
  String get planUsageAi => 'Assistant this month';

  @override
  String planLimitAi(String used, String limit) {
    return 'You used $used of $limit assistant requests this month. To keep going now, see the plans.';
  }

  @override
  String aiIntroTitle(String order) {
    return 'Create your next $order by talking';
  }

  @override
  String get aiIntroBody =>
      'Say the customer and the service, or take a photo. The app fills it in and you just check it before saving.';

  @override
  String get aiIntroTry => 'Try it now';

  @override
  String get aiIntroLater => 'Not now';

  @override
  String get courtesyBannerLabel => 'Pro plan courtesy';

  @override
  String courtesyBannerEnds(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Ends in $days days.',
      one: 'Ends in 1 day.',
    );
    return '$_temp0';
  }

  @override
  String courtesyBannerOrdersUse(int used, int free) {
    String _temp0 = intl.Intl.pluralLogic(
      used,
      locale: localeName,
      other:
          'You opened $used work orders this month; Free includes $free a month.',
      one: 'You opened 1 work order this month; Free includes $free a month.',
    );
    return '$_temp0';
  }

  @override
  String get courtesyBannerToFree =>
      'After that, the app goes back to the Free plan.';

  @override
  String courtesyBannerPlan(String plan) {
    return 'The $plan plan covers your use.';
  }

  @override
  String get courtesyBannerLater => 'Not now';

  @override
  String deviceSaveNeedsAny(String first, String second) {
    return 'Fill in $first or $second to save.';
  }

  @override
  String orderStatusVisit(String status, String date) {
    return '$status · visit $date';
  }

  @override
  String get orderOpenChecklist => 'Open checklist';

  @override
  String orderPdfTitle(String order, String number) {
    return '$order $number';
  }

  @override
  String get receivePaymentMethod => 'Payment method';

  @override
  String get receivePaymentMethodOptional => 'Optional';

  @override
  String get receivePaymentMethodQuestion => 'How was it paid?';

  @override
  String get receivePaymentMethodNone => 'Don\'t specify';

  @override
  String get paymentMethodPix => 'Pix';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodCard => 'Card';

  @override
  String get paymentMethodOther => 'Other';

  @override
  String get filterQuotes => 'Quotes';

  @override
  String homeQuotesWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quotes waiting for an answer',
      one: '1 quote waiting for an answer',
    );
    return '$_temp0';
  }

  @override
  String get noQuotesWaiting => 'No quotes waiting for an answer.';

  @override
  String ratingsEmptyHint(String order) {
    return 'A rating arrives when the customer scores the $order through its link, once it is done. To ask for one, open a completed $order and send the customer the link.';
  }

  @override
  String noticesEmptyHint(String order) {
    return 'This is where you see what happens in your $order: customer approvals, comments, ratings and payments. Reminders of scheduled times go straight to your phone.';
  }

  @override
  String get noticesRemindersLink => 'Adjust reminders';

  @override
  String reminderWillNotify(String time) {
    return 'The app reminds you $time before.';
  }

  @override
  String get reminderIsOff => 'Reminder turned off.';

  @override
  String get reminderPhoneBlocked =>
      'Notifications are off in your phone\'s Settings.';

  @override
  String get reminderAdjust => 'Adjust';

  @override
  String reminderNotificationTitle(String time) {
    return 'Scheduled at $time';
  }

  @override
  String get notificationPromptTitle => 'PraticOS notifications';

  @override
  String get notificationPromptMessage =>
      'The app reminds you before each scheduled time and tells you when a customer approves a quote. Your phone will ask if it can send these notifications.';

  @override
  String get continueAction => 'Continue';

  @override
  String get checklistOfferTitle => 'Fill in the check-in checklist?';

  @override
  String checklistOfferMessage(String device) {
    return 'Record how $device arrived, before you start the work.';
  }

  @override
  String get checklistOfferAction => 'Fill in checklist';

  @override
  String get moreContractsSubtitle => 'Maintenance that repeats on its own';

  @override
  String get contractsOffQuestion =>
      'Do you have regular customers or repeat maintenance?';

  @override
  String contractsOffMessage(String order) {
    return 'With contracts you set it up once, say every 6 months, and the app takes care of the next $order on the right date.';
  }

  @override
  String get contractsOffAction => 'Use contracts';

  @override
  String get filterOnHold => 'On hold';

  @override
  String homeOnHoldCount(int count) {
    return '$count on hold';
  }

  @override
  String get noOrdersOnHold => 'Nothing on hold.';

  @override
  String get orderHoldMark => 'Put on hold';

  @override
  String get orderHoldResume => 'Resume work';

  @override
  String get orderHoldSaveError => 'Could not save. Try again.';

  @override
  String orderStageMoveTo(String stage) {
    return 'Move to $stage';
  }

  @override
  String get orderMenuChangeStage => 'Change stage';

  @override
  String get orderStagePickerTitle => 'Which stage is it in?';

  @override
  String get orderStageSaveError =>
      'Could not change the stage. Check the connection and try again.';

  @override
  String get orderHoldSheetTitle => 'Why did it stop?';

  @override
  String get orderHoldNoteHint => 'Note (optional)';

  @override
  String get orderHoldReasonPart => 'Waiting for a part';

  @override
  String get orderHoldReasonCustomer => 'Waiting for the customer';

  @override
  String get orderHoldReasonAuthorization => 'Waiting for authorization';

  @override
  String get orderHoldReasonOther => 'Other reason';

  @override
  String orderHoldSince(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'On hold for $count days',
      one: 'On hold for 1 day',
      zero: 'On hold since today',
    );
    return '$_temp0';
  }

  @override
  String orderHoldLogMarked(String reason) {
    return 'Put on hold: $reason';
  }

  @override
  String orderHoldLogResumed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Resumed after $count days on hold',
      one: 'Resumed after 1 day on hold',
      zero: 'Resumed the same day',
    );
    return '$_temp0';
  }

  @override
  String get aiActionsTitle => 'Look right?';

  @override
  String aiActionsReceive(String amount) {
    return 'Receive $amount';
  }

  @override
  String get aiActionsReceiveNoAmount => 'Receive';

  @override
  String aiActionsReceived(String amount) {
    return 'Received $amount';
  }

  @override
  String get aiActionsTypeAmount => 'tap to enter the amount';

  @override
  String aiActionsLeft(String amount) {
    return '$amount left';
  }

  @override
  String get aiActionsPaidOff => 'paid off';

  @override
  String aiActionsDiscount(String amount) {
    return '$amount discount';
  }

  @override
  String aiActionsNewTotal(String amount) {
    return 'total $amount';
  }

  @override
  String aiActionsMarkAs(String status) {
    return 'Mark as $status';
  }

  @override
  String get aiActionsIssuesNfse => 'This also issues the invoice.';

  @override
  String get aiActionsCannotReceive =>
      'Only people who receive payments can record this.';

  @override
  String get aiActionsCannotDiscount =>
      'Only people who handle finances can give a discount.';

  @override
  String get aiActionsOrderCanceled => 'This order is canceled.';

  @override
  String get aiActionsNothingToReceive => 'This order has nothing to receive.';

  @override
  String aiActionsOnlyLeft(String amount) {
    return 'Only $amount left.';
  }

  @override
  String get aiActionsAfterSave => 'When you save, I\'ll ask you to check it.';

  @override
  String get aiActionsSaving => 'Saving…';

  @override
  String get aiActionsSavedOffline =>
      'Order saved. Record the payment when you\'re online.';

  @override
  String aiActionsStatusKept(String status) {
    return 'The status stays $status.';
  }

  @override
  String get aiActionsNfseStays => 'The invoice stays issued.';

  @override
  String get nextMaintenanceQuestion => 'When is the next maintenance?';

  @override
  String get nextMaintenanceThreeMonths => '3 months';

  @override
  String get nextMaintenanceSixMonths => '6 months';

  @override
  String get nextMaintenanceOneYear => '1 year';

  @override
  String get nextMaintenanceNoRepeat => 'Don\'t repeat';

  @override
  String nextMaintenanceCurrent(String date) {
    return 'Set for $date';
  }

  @override
  String nextMaintenanceOn(String date) {
    return 'Next maintenance: $date';
  }

  @override
  String get nextMaintenanceSet => 'Set next maintenance';

  @override
  String get nextMaintenanceChangeHint => 'Tap to change or remove';

  @override
  String get nextMaintenanceRemove => 'Remove';

  @override
  String get nextMaintenanceByContract => 'From the contract';

  @override
  String get nextMaintenanceSaveError => 'Couldn\'t save the maintenance date';

  @override
  String get orderStatusSaveError => 'Couldn\'t save. Try again.';

  @override
  String get maintenanceComing => 'Maintenance coming up';

  @override
  String maintenanceShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count more',
      one: 'Show 1 more',
    );
    return '$_temp0';
  }

  @override
  String get maintenanceCallCustomer => 'Contact customer';

  @override
  String get maintenanceOpenOrder => 'Open order';

  @override
  String maintenanceViewDevice(String device) {
    return 'View $device';
  }

  @override
  String get maintenanceNoPhone => 'Customer has no phone';

  @override
  String get maintenanceWhatsappError => 'Couldn\'t open WhatsApp';

  @override
  String maintenanceWhatsappMessage(
    String customer,
    String device,
    String date,
  ) {
    return 'Hi $customer! The maintenance of $device is coming up, planned for $date. Can we pick a day?';
  }

  @override
  String maintenanceWhatsappMessageNoName(String device, String date) {
    return 'Hi! The maintenance of $device is coming up, planned for $date. Can we pick a day?';
  }

  @override
  String maintenanceLastService(String service) {
    return 'Last: $service';
  }

  @override
  String get orderCreateFailedTitle => 'Couldn\'t save the work order';

  @override
  String get orderCreateFailedMessage =>
      'Check your connection and create the work order again.';

  @override
  String get receiveChargeMaybeOpen =>
      'There may be an open payment link on this work order. Check with whoever handles billing before marking it as received.';

  @override
  String get checklistAnswerSaveFailed =>
      'Couldn\'t save the answer. Try again.';

  @override
  String checklistReadingBelowLastVisit(String reading) {
    return 'Lower than the $reading of the last visit. Is that right?';
  }

  @override
  String get profileSaveFailed => 'Couldn\'t save your profile. Try again.';

  @override
  String get saveFailedTryAgain => 'Couldn\'t save. Try again.';

  @override
  String get deleteFailedTryAgain => 'Couldn\'t delete. Try again.';

  @override
  String get nfseDirectHeadEmpty =>
      'Send your digital certificate to issue invoices';

  @override
  String get nfseDirectHeadWithEmitters =>
      'Invoices go out from the CNPJ you pick each time';

  @override
  String get nfseDirectEmittersSection => 'Your CNPJs';

  @override
  String get nfseDirectAddCnpjTitle => 'Add CNPJ';

  @override
  String get nfseDirectAddCnpjIntro =>
      'Pick the CNPJ\'s A1 digital certificate and type its password. PraticOS finds the rest.';

  @override
  String get nfseDirectReplaceTitle => 'Replace certificate';

  @override
  String nfseDirectReplaceIntro(String name) {
    return 'Pick the new certificate of $name and type its password.';
  }

  @override
  String get nfseDirectSendCertificate => 'Send certificate';

  @override
  String get nfseDirectCertificateFile => 'Certificate file';

  @override
  String get nfseDirectPickFile => 'Choose';

  @override
  String get nfseDirectCertificatePassword => 'Certificate password';

  @override
  String get nfseDirectCertificatePasswordHint =>
      'Used only to send. PraticOS does not keep the password.';

  @override
  String get nfseDirectUploadMissing =>
      'Choose the file, type the password and accept the terms to send.';

  @override
  String get nfseDirectTerms =>
      'PraticOS uses the certificate only to issue and read your invoices. You can delete it at any time.';

  @override
  String get nfseDirectTermsLink => 'Read the terms';

  @override
  String get nfseDirectCnpjAdded => 'CNPJ added';

  @override
  String get nfseDirectCertificateReplaced => 'Certificate replaced';

  @override
  String get nfseDirectCertificateDeleted => 'Certificate deleted';

  @override
  String get nfseDirectRegimeMei => 'MEI';

  @override
  String get nfseDirectRegimeSimples => 'Simples';

  @override
  String get nfseDirectDefault => 'Default';

  @override
  String get nfseDirectDefaultSaved =>
      'Invoices use this CNPJ when the customer has no other';

  @override
  String get nfseDirectUseAsDefault => 'Use as default';

  @override
  String nfseDirectCertValidUntil(String date) {
    return 'Certificate valid until $date';
  }

  @override
  String nfseDirectCertExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Certificate expires in $days days',
      one: 'Certificate expires tomorrow',
    );
    return '$_temp0';
  }

  @override
  String get nfseDirectCertExpired => 'Certificate expired';

  @override
  String get nfseDirectCertPending =>
      'Certificate waiting for your confirmation';

  @override
  String get nfseDirectCertMissing => 'No certificate';

  @override
  String nfseDirectCertExpiresOn(String date) {
    return 'Expires on $date';
  }

  @override
  String nfseDirectCertExpiredOn(String date) {
    return 'Expired on $date';
  }

  @override
  String nfseDirectCertSentBy(String expires, String name, String date) {
    return '$expires · sent by $name on $date';
  }

  @override
  String get nfseDirectAutoIssueRow =>
      'Issue automatically when the order is done';

  @override
  String get nfseDirectAutoIssueQuestion =>
      'When does the invoice go out by itself?';

  @override
  String get nfseDirectAutoIssueNever => 'Never';

  @override
  String get nfseDirectAutoIssueNeverHint =>
      'You issue it from the order, with one tap';

  @override
  String get nfseDirectAutoIssueSelected => 'For the customers you choose';

  @override
  String get nfseDirectAutoIssueSelectedHint => 'Turn it on in each customer';

  @override
  String get nfseDirectAutoIssueAll => 'For every order';

  @override
  String get nfseDirectAutoIssueAllHint => 'Goes out when the order is done';

  @override
  String get nfseDirectEmitterTitle => 'CNPJ';

  @override
  String nfseDirectTotals(String year, String month) {
    return 'Invoices this year: $year · this month: $month';
  }

  @override
  String nfseDirectMeiLimit(String value, String limit) {
    return 'Billed $value of $limit this year (from invoices)';
  }

  @override
  String nfseDirectNotEnabledInCity(String city) {
    return 'Not yet enabled to issue in $city';
  }

  @override
  String get nfseDirectNotEnabledNoCity =>
      'We haven\'t checked yet whether this CNPJ can issue notas through the government.';

  @override
  String get nfseDirectServiceRow => 'Invoice service';

  @override
  String get nfseDirectServiceName => 'Service name';

  @override
  String get nfseDirectServiceNamePlaceholder => 'E.g. Vehicle maintenance';

  @override
  String get nfseDirectServiceCode => 'Service code';

  @override
  String get nfseDirectServiceCodeHint =>
      '6 digits from the national list. Your accountant knows it.';

  @override
  String get nfseDirectServiceMissing =>
      'Type the name and the 6-digit code to save.';

  @override
  String get nfseDirectRegistrationRow => 'Municipal registration';

  @override
  String get nfseDirectRegistrationHint =>
      'Leave empty if the city does not use it.';

  @override
  String get nfseDirectStyleRow => 'Description style';

  @override
  String get nfseDirectStyleHead => 'How the services show on the invoice';

  @override
  String get nfseDirectStyleUppercase => 'All capitals';

  @override
  String get nfseDirectStyleSeparator => 'Separate services with';

  @override
  String get nfseDirectSeparatorQuestion => 'How to separate the services?';

  @override
  String nfseDirectStyleSample(String sample) {
    return 'It looks like: $sample';
  }

  @override
  String get nfseDirectSampleService1 => 'Service 1';

  @override
  String get nfseDirectSampleService2 => 'Service 2';

  @override
  String get nfseDirectCertificateRow => 'Certificate';

  @override
  String get nfseDirectMissing => 'Missing';

  @override
  String get nfseDirectNone => 'None';

  @override
  String get nfseDirectSaved => 'Saved';

  @override
  String get nfseDirectDeleteAction => 'Delete certificate';

  @override
  String get nfseDirectDeleteTitle => 'Delete the certificate?';

  @override
  String nfseDirectDeleteMessage(String name) {
    return 'The certificate of $name is deleted for good and can no longer issue invoices. The invoices stay.';
  }

  @override
  String get nfseDirectErrorInvalidFile =>
      'This file is not an A1 certificate. Choose the .pfx or .p12 file.';

  @override
  String get nfseDirectErrorWrongPassword =>
      'Wrong password. Check with whoever sent the certificate.';

  @override
  String get nfseDirectErrorExpired =>
      'This certificate has expired. Ask your accountant for a new one.';

  @override
  String get nfseDirectErrorNotYetValid => 'This certificate is not valid yet.';

  @override
  String get nfseDirectErrorNotIcpBrasil =>
      'This certificate is not from ICP-Brasil. Use the company\'s A1 certificate.';

  @override
  String get nfseDirectErrorNoTaxId =>
      'This certificate is not of a CNPJ. Use the company\'s A1 certificate.';

  @override
  String get nfseDirectErrorOtherTaxId =>
      'This certificate is of another CNPJ. To replace, use one of the same CNPJ.';

  @override
  String get nfseDirectErrorAlreadyExists =>
      'This CNPJ is already added. To renew, open it and replace the certificate.';

  @override
  String get nfseDirectErrorNotFound => 'This CNPJ is no longer added.';

  @override
  String get nfseDirectErrorNotEnabled =>
      'Invoices are not turned on for your company yet.';

  @override
  String get nfseDirectErrorForbidden =>
      'Only the owner and admins can change this.';

  @override
  String get nfseDirectErrorValidation => 'Check what was typed and try again.';

  @override
  String get nfseDirectErrorUnavailable =>
      'Could not send now. Try again in a few minutes.';

  @override
  String get nfseDirectErrorGeneric => 'That did not work. Try again.';

  @override
  String get nfseDirectServiceCodePlaceholder => 'E.g. 140101';

  @override
  String nfseDirectSeparatorValue(String separator) {
    return '“$separator”';
  }

  @override
  String get invoiceDataTitle => 'Invoice details';

  @override
  String get invoiceDataHint =>
      'Tax ID, legal name and address for the invoice';

  @override
  String get invoiceLegalName => 'Legal name';

  @override
  String get invoiceLegalNamePlaceholder => 'E.g. SAMPLE DEALER LTDA';

  @override
  String get invoicePostalCode => 'ZIP code';

  @override
  String get invoicePostalCodePlaceholder => '00000-000';

  @override
  String get invoiceStreet => 'Street';

  @override
  String get invoiceNumber => 'Number';

  @override
  String get invoiceComplement => 'Address line 2';

  @override
  String get invoiceDistrict => 'District';

  @override
  String get invoiceCity => 'City';

  @override
  String get invoiceState => 'State';

  @override
  String get invoiceStatePlaceholder => 'SP';

  @override
  String get invoiceEmailLabel => 'Invoice e-mail';

  @override
  String get invoiceEmailFallback =>
      'If empty, the invoice goes to the customer\'s e-mail';

  @override
  String get invoiceTaxIdLooking => 'Looking up the CNPJ…';

  @override
  String get invoiceTaxIdFound =>
      'Filled with the Receita\'s data. Check before saving.';

  @override
  String get invoiceTaxIdNotFound =>
      'We couldn\'t find this CNPJ. Fill it in by hand.';

  @override
  String get invoicePostalCodeLooking => 'Looking up the ZIP code…';

  @override
  String get invoicePostalCodeNotFound =>
      'We couldn\'t find this ZIP code. Fill it in by hand.';

  @override
  String get invoiceRecipientLabel => 'Invoice to';

  @override
  String get invoiceRecipientAction => 'Send the invoice to another customer';

  @override
  String get invoiceRecipientPickerTitle => 'Who gets the invoice?';

  @override
  String get invoiceRecipientNone =>
      'None: the invoice goes to the customer itself';

  @override
  String get invoiceAutoIssue => 'Issue invoice by itself';

  @override
  String get invoiceAutoIssueHint => 'When the order is done';

  @override
  String invoiceTaxIdTakenCnpj(String name) {
    return '$name already has this CNPJ';
  }

  @override
  String invoiceTaxIdTakenCpf(String name) {
    return '$name already has this CPF';
  }

  @override
  String get invoiceTaxIdTakenMessage =>
      'Each CPF or CNPJ belongs to one customer only.';

  @override
  String get invoiceTaxIdTakenUse => 'Send this store\'s invoices to it';

  @override
  String invoiceRecipientSet(String customer, String recipient) {
    return '$customer\'s invoices go to $recipient';
  }

  @override
  String invoiceRecipientCleared(String customer) {
    return '$customer\'s invoices go to the customer itself';
  }

  @override
  String nfseDirectCpfLine(String value) {
    return 'CPF $value';
  }

  @override
  String nfseDirectCnpjLine(String value) {
    return 'CNPJ $value';
  }

  @override
  String get nfseDirectProblemCertificate => 'No digital certificate';

  @override
  String get nfseDirectProblemNotEnabled => 'Not enabled to issue in the city';

  @override
  String get nfseDirectProblemService => 'The invoice service is missing';

  @override
  String get nfseDirectProblemSetup => 'This CNPJ\'s setup is not finished';

  @override
  String nfseDirectIssueCannot(String reason) {
    return 'This CNPJ can\'t issue now: $reason';
  }

  @override
  String get nfseDirectIssueCityByPostalCode =>
      'Type the CEP to find the city.';

  @override
  String get nfseDirectIssueAddressMissing =>
      'The recipient\'s address with CEP is missing.';

  @override
  String get nfseDirectIssueEmailMissing =>
      'The recipient\'s e-mail is missing.';

  @override
  String get nfseDirectIssueEmitterQuestion => 'Issue under which CNPJ?';

  @override
  String get nfseDirectIssueRecipientQuestion => 'Who gets this invoice?';

  @override
  String get nfseDirectIssueRecipientOnlyThis => 'Only for this invoice';

  @override
  String get nfseDirectRefusedGeneric => 'The government refused the invoice.';

  @override
  String get nfseDirectRefusedFixRecipient =>
      'Check the recipient\'s data and tap ✓ again.';

  @override
  String get nfseDirectIssueBy => 'Issue under';

  @override
  String get nfseDirectIssueTo => 'To';

  @override
  String nfseDirectIssueViaRecipient(String name) {
    return 'Through the “Invoice to” of $name';
  }

  @override
  String get nfseDirectMeiNear =>
      'With this invoice, the MEI goes over 80% of the yearly limit.';

  @override
  String get nfseDirectMeiOver =>
      'With this invoice, the MEI goes over the yearly limit. Talk to your accountant.';

  @override
  String nfseDirectIssueRecipientDataIntro(String name) {
    return '$name is missing data for the invoice. It\'s saved on the customer.';
  }

  @override
  String nfseDirectIssueComplementary(String info) {
    return 'Also on the invoice: $info';
  }

  @override
  String get nfseDirectIssuedToast => 'Invoice issued';

  @override
  String get nfseDirectWaitingToast =>
      'The government hasn\'t answered yet. The invoice shows up as soon as it confirms.';

  @override
  String get nfseDirectErrorRecipientTaxId =>
      'The recipient\'s CPF or CNPJ is missing.';

  @override
  String get nfseDirectErrorEmitterNotReady =>
      'This CNPJ can\'t issue yet. Check the invoice setup.';

  @override
  String get nfseDirectErrorManagerNotAllowed =>
      'The owner hasn\'t allowed managers to issue invoices. Ask the owner to issue it or allow it.';

  @override
  String get nfseDirectErrorOrderHasInvoice =>
      'This order already has an invoice.';

  @override
  String get nfseDirectErrorGovUnavailable =>
      'The government didn\'t answer. Try again in a few minutes.';

  @override
  String get nfseDirectErrorNotCancelable => 'This invoice can\'t be canceled.';

  @override
  String get nfseDirectErrorPdf => 'This invoice\'s PDF isn\'t ready yet.';

  @override
  String get nfseDirectCancelPortal =>
      'The city didn\'t accept the cancellation here. Cancel it on the government portal (nfse.gov.br).';

  @override
  String get nfseDirectCancelMessage =>
      'Pick the reason. The government records it right away and the invoice stops being valid.';

  @override
  String get nfseDirectCancelReasonIssueError => 'Mistake in the invoice';

  @override
  String get nfseDirectCancelReasonNotProvided => 'Service not provided';

  @override
  String get nfseDirectCancelReasonRow => 'Reason';

  @override
  String get nfseDirectEmitterLabel => 'Issued by';

  @override
  String get nfseDirectAccessKeyLabel => 'Access key';

  @override
  String get nfseDirectExternalTag => 'Issued outside PraticOS';

  @override
  String get nfseDirectCheckNow => 'Check now';

  @override
  String get nfseDirectFilterRow => 'CNPJ';

  @override
  String get nfseDirectFilterAll => 'All';

  @override
  String get nfseDirectFilterQuestion => 'Invoices of which CNPJ?';

  @override
  String get nfseImportTitle => 'Import notas';

  @override
  String get nfseImportReading => 'Reading your notas from the government…';

  @override
  String nfseImportReadingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents read',
      one: '1 document read',
      zero: 'Starting',
    );
    return '$_temp0';
  }

  @override
  String nfseImportHeadline(int notas, int customers) {
    return 'We found $notas notas for $customers customers. We will fill in your customers and the nota\'s service.';
  }

  @override
  String get nfseImportHeadlineEmpty =>
      'We found no notas of this CNPJ at the government. We will fill in the nota\'s service and series.';

  @override
  String get nfseImportEmitterSection => 'Issuer';

  @override
  String get nfseImportServiceRow => 'Most used service';

  @override
  String nfseImportServiceValue(String name, String rate) {
    return '$name · ISS $rate';
  }

  @override
  String get nfseImportSeriesRow => 'Series of the PraticOS notas';

  @override
  String get nfseImportCustomersSection => 'Customers';

  @override
  String nfseImportCustomersNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new customers',
      one: '1 new customer',
    );
    return '$_temp0';
  }

  @override
  String nfseImportCustomersCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count complete customers you already have',
      one: '1 completes a customer you already have',
    );
    return '$_temp0';
  }

  @override
  String get nfseImportCustomersHint =>
      'We only fill what is empty. Nothing you typed changes.';

  @override
  String get nfseImportAskSection => 'Is this the same customer?';

  @override
  String nfseImportAskSubtitle(String customer) {
    return 'Is it your customer $customer?';
  }

  @override
  String get nfseImportAskUnanswered => 'Answer';

  @override
  String get nfseImportAskSame => 'Yes';

  @override
  String get nfseImportAskNew => 'No, create another';

  @override
  String get nfseImportAskHint =>
      'Without an answer, it becomes a new customer.';

  @override
  String get nfseImportStoresSection => 'Stores billed on another CNPJ';

  @override
  String nfseImportStoreRow(String recipient) {
    return 'Nota fiscal to $recipient';
  }

  @override
  String get nfseImportAutoSection => 'Issue by itself';

  @override
  String nfseImportAutoQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'These $count customers had a nota on almost every order. Turn on the automatic nota for them?',
      one:
          'This customer had a nota on almost every order. Turn on the automatic nota for them?',
    );
    return '$_temp0';
  }

  @override
  String get nfseImportNotasSection => 'Notas';

  @override
  String nfseImportNotasLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linked to your orders',
      one: '1 linked to your orders',
    );
    return '$_temp0';
  }

  @override
  String nfseImportNotasHistory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count only in the history',
      one: '1 only in the history',
    );
    return '$_temp0';
  }

  @override
  String get nfseImportButton => 'Import';

  @override
  String get nfseImportDone => 'Notas imported';

  @override
  String get nfseImportAction => 'Import notas from the government';

  @override
  String get nfseImportUndoAction => 'Undo import';

  @override
  String get nfseImportUndoQuestion => 'Undo the import?';

  @override
  String get nfseImportUndoMessage =>
      'We delete the customers created that have no orders yet, empty what was filled in and unlink the notas from the orders. The notas stay in the history.';

  @override
  String get nfseImportUndone => 'Import undone';

  @override
  String get nfseImportErrorUndoExpired =>
      'The import is more than 30 days old and can no longer be undone.';

  @override
  String get nfseLinkOrderRow => 'Order';

  @override
  String get nfseLinkOrderAction => 'Link to an order';

  @override
  String get nfseLinkPickerTitle => 'Which order is this nota for?';

  @override
  String get nfseLinkPickerSame => 'Of the customer';

  @override
  String get nfseLinkPickerOthers => 'Others';

  @override
  String get nfseLinkPickerEmpty => 'No order to link';

  @override
  String nfseLinkOrderTitle(String number) {
    return 'Order $number';
  }

  @override
  String get nfseLinkHasNota => 'Already has a nota';

  @override
  String get nfseLinked => 'Nota linked to the order';

  @override
  String get nfseUnlinkAction => 'Unlink from the order';

  @override
  String nfseUnlinkQuestion(String numbers) {
    return 'Unlink the nota from order $numbers?';
  }

  @override
  String get nfseUnlinkMessage =>
      'The order is free for another nota. The nota stays in the history.';

  @override
  String get nfseUnlinked => 'Nota unlinked from the order';

  @override
  String get nfseLinkErrorOrderHasNota =>
      'This order already has a nota. Cancel the other one first.';

  @override
  String get nfseLinkErrorAlreadyLinked =>
      'This nota is already linked to an order.';

  @override
  String get nfseDirectAcceptTerms =>
      'I have read and accept the certificate terms';

  @override
  String get nfseDirectErrorTooManyAttempts =>
      'Too many tries to send the certificate. Wait an hour and try again.';

  @override
  String get nfseDirectErrorBusy =>
      'Someone else is changing this certificate right now. Try again in a few minutes.';

  @override
  String get nfseDirectErrorDailyLimit =>
      'This company reached today\'s invoice limit. It can issue again tomorrow; if you need more, contact support.';

  @override
  String get nfseDirectErrorOwnerOnly =>
      'Only the account owner can change this.';

  @override
  String get nfseDirectManagerCanIssue => 'Managers can issue invoices';

  @override
  String get nfseDirectManagerCanIssueHint =>
      'You get a notice whenever someone else issues or cancels an invoice.';

  @override
  String get nfseEmailRow => 'Email to the customer';

  @override
  String nfseEmailSentTo(String email, String date) {
    return 'Sent to $email on $date';
  }

  @override
  String nfseEmailCancelSentTo(String email, String date) {
    return 'Cancellation notice sent to $email on $date';
  }

  @override
  String nfseEmailFailedTo(String email, String date) {
    return 'Could not send to $email on $date';
  }

  @override
  String get nfseEmailSkippedNoEmail =>
      'Not sent: the customer has no email on file';

  @override
  String get nfseEmailSkippedTurnedOff => 'Not sent: automatic sending is off';

  @override
  String get nfseEmailNotSentYet => 'Not sent by email yet';

  @override
  String get nfseEmailSendAgain => 'Send again';

  @override
  String get nfseEmailSend => 'Send';

  @override
  String get nfseIssuingProgress =>
      'Issuing the invoice… it may take a few seconds.';

  @override
  String get nfseCancelingProgress => 'Canceling the invoice…';

  @override
  String get nfseEmailSendingProgress => 'Sending the e-mail…';

  @override
  String nfseEmailSentToast(String email) {
    return 'Invoice sent to $email';
  }

  @override
  String get nfseEmailFailedToast =>
      'Could not send the email. Try again in a moment.';

  @override
  String get nfseEmailNoAddressToast =>
      'The customer has no email. Add it to their record and send again.';

  @override
  String get nfseDirectEmailToCustomer => 'Email the invoice to the customer';

  @override
  String get nfseDirectEmailToCustomerHint =>
      'Goes out on its own when issued or canceled, with the PDF and XML. Turn it off if you send it by WhatsApp.';

  @override
  String nfseDirectIssueEmailGoesTo(String email) {
    return 'The invoice will be emailed to $email.';
  }

  @override
  String get nfseDirectIssueEmailOff =>
      'The invoice will not be emailed: automatic sending is off.';

  @override
  String deviceReadingLine(String label, String value) {
    return '$label: $value';
  }

  @override
  String get orderItemCatalogPriceTitle => 'Change the price in the Catalog?';

  @override
  String orderItemCatalogPriceMessage(
    String entity,
    String name,
    String from,
    String to,
  ) {
    return '$entity “$name” costs $from in the Catalog. Use $to always or only on this order?';
  }

  @override
  String get orderItemCatalogPriceAlways => 'Use always';

  @override
  String get orderItemCatalogPriceOnlyHere => 'Only this order';

  @override
  String orderItemCatalogPriceSaved(String to) {
    return 'Catalog price changed to $to';
  }

  @override
  String get orderItemCatalogPriceFailed =>
      'Couldn\'t change the price in the Catalog. Change it there.';

  @override
  String get sharePreview => 'See what the customer sees';

  @override
  String get sharePreviewFailed => 'Couldn\'t open the preview. Try again.';

  @override
  String checklistStatusDoneMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Done · $count unanswered',
      one: 'Done · 1 unanswered',
    );
    return '$_temp0';
  }

  @override
  String get checklistDoneTitle => 'Checklist done';

  @override
  String get checklistDoneReopenBody =>
      'To change an answer, reopen the checklist.';

  @override
  String get checklistDoneAskReopenBody =>
      'To change an answer, ask whoever manages the team to reopen the checklist.';

  @override
  String get statementSend => 'Send statement';

  @override
  String statementSendTitle(String name) {
    return 'Send $name what is still owed';
  }

  @override
  String get statementSendMessage =>
      'A message goes with the checked orders and how much is owed on each. Send the PDF too?';

  @override
  String get statementWithPdf => 'Send with PDF';

  @override
  String get statementTextOnly => 'Text only';

  @override
  String statementTextHello(String name, String company) {
    return 'Hi $name! These are your open orders with $company:';
  }

  @override
  String statementTextHelloNoCompany(String name) {
    return 'Hi $name! These are your open orders:';
  }

  @override
  String statementOrderNumber(String number) {
    return 'Order $number';
  }

  @override
  String statementOpenLine(String amount) {
    return 'Owed $amount';
  }

  @override
  String get statementInProgress => 'in progress';

  @override
  String statementTotalOpen(String amount) {
    return 'Total owed: $amount';
  }

  @override
  String get statementPdfTitle => 'Statement';

  @override
  String statementPdfSentence(String name, String date) {
    return 'Open orders of $name on $date.';
  }

  @override
  String get statementItemColumn => 'Service or part';

  @override
  String statementOrderTotals(String total, String paid, String open) {
    return 'Total $total  ·  Paid $paid  ·  Owed $open';
  }

  @override
  String get statementPdfTotalOpen => 'Total owed';

  @override
  String statementFileName(String date) {
    return 'Statement-$date';
  }

  @override
  String get customersOrderRecent => 'Most recent';

  @override
  String get customersOrderName => 'Name (A–Z)';

  @override
  String get customersSortBy => 'Sort by';

  @override
  String customerShowAllDevices(int count, String devices) {
    return 'See all $count $devices';
  }

  @override
  String customerShowAllOrders(int count) {
    return 'See all $count orders';
  }

  @override
  String get customerShowLess => 'Show less';

  @override
  String get customerSearchDevices => 'Search by name or plate';

  @override
  String get customerSearchOrders => 'Search by order number';

  @override
  String get filterLate => 'Late';

  @override
  String get filterUnpaid => 'To receive';

  @override
  String get noLateOrders => 'Nothing late.';

  @override
  String get noUnpaidOrders => 'Nothing to receive.';

  @override
  String get checklistNoteAdd => '+ Note';

  @override
  String get checklistNote => 'Note';

  @override
  String get checklistNotePlaceholder => 'What you saw and where';

  @override
  String checklistNotePhoto(int number) {
    return 'Photo $number';
  }

  @override
  String checklistNoteLine(String label, String text) {
    return '$label: $text';
  }

  @override
  String get checklistAiReading => 'Reading the photo…';

  @override
  String checklistAiFilled(String summary) {
    return 'Filled in: $summary';
  }

  @override
  String get checklistAiFilledMark => 'Filled in by AI';

  @override
  String checklistAiSeenAlso(String text) {
    return 'AI also saw: $text';
  }

  @override
  String get checklistAiAppend => 'Add';

  @override
  String checklistAiDiffers(String answer) {
    return 'The photo shows: $answer';
  }

  @override
  String get checklistAiUseAnswer => 'Replace';

  @override
  String get checklistAiDark => 'Photo too dark to read';

  @override
  String get checklistAiBlurry => 'Photo too blurry to read';

  @override
  String get checklistAiOffTarget =>
      'The photo doesn\'t show what the question asks';

  @override
  String get checklistAiRetake => 'Retake';

  @override
  String get checklistAiFailed => 'Couldn\'t read the photo right now';

  @override
  String get checklistAiQuota => 'This month\'s AI readings are used up';

  @override
  String get checklistAiNothing => 'AI didn\'t find the answer in the photo';

  @override
  String get checklistAiView => 'View';

  @override
  String planFeatureTitle(String plan) {
    return 'Part of the $plan plan';
  }

  @override
  String planFeatureBody(String plan) {
    return 'To use it, move to the $plan plan. What you already have stays.';
  }

  @override
  String planFeatureAskOwner(String plan) {
    return 'Ask the business owner to move to the $plan plan.';
  }

  @override
  String planFeatureBadge(String plan) {
    return '$plan plan';
  }

  @override
  String get planFeatureNfse => 'Service invoices (NFS-e)';

  @override
  String get planFeatureBrandedPdf => 'PDF without the PraticOS brand';

  @override
  String get planFeatureOwnChecklists => 'Your own checklists';

  @override
  String get planFeatureCharges => 'Payment requests and reminders';

  @override
  String get planFeatureReviewRequest => 'Ask the customer for a review';

  @override
  String get planFeatureTeamRoles => 'Technician, manager and other roles';

  @override
  String get planFeaturePerPersonAgenda => 'Schedule and assignee per person';

  @override
  String get planFeatureWorkStages => 'Work stages';

  @override
  String get planFeatureTvMode => 'TV mode';

  @override
  String get planFeatureContracts => 'Contracts';

  @override
  String get planFeatureAiFinance => 'AI for payments';

  @override
  String get planFeatureSpreadsheetExport => 'Spreadsheet report';

  @override
  String get planFeatureBulkActions => 'Bulk actions';

  @override
  String get planFeatureMcp => 'ChatGPT and Claude';

  @override
  String get planFeatureApi => 'API with a key';

  @override
  String get planUsageOrders => 'Orders this month';

  @override
  String get planUsageTaxIds => 'Tax IDs on invoices';

  @override
  String planNoticeOrdersNear(String used, String limit) {
    return 'You have opened $used of $limit orders this month.';
  }

  @override
  String planNoticeOrdersAtLimit(String limit) {
    return 'You have opened the $limit orders of the month. You can keep opening this month; if you go over again next month, new orders wait until you change plans.';
  }

  @override
  String planNoticeOrdersGrace(String limit) {
    return 'This month went over $limit orders and nothing was blocked. If you go over again next month, new orders wait until you change plans.';
  }

  @override
  String planNoticeOrdersBlocked(String limit) {
    return 'Over $limit orders again. Open orders work as usual; a new one waits until you change plans.';
  }

  @override
  String planNoticeOrdersContactUs(String limit) {
    return 'This month went over the $limit work orders included in Business.';
  }

  @override
  String planNoticePeopleContactUs(String limit) {
    return 'Your team went over the $limit people included in Business.';
  }

  @override
  String planNextTitle(String plan) {
    return 'What $plan adds';
  }
}
