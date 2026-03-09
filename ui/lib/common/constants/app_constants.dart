/// Classe com todas as chaves de tradução da aplicação
/// Use AppConstants.key.tr() para obter o texto traduzido
class AppConstants {
  // ===== APP =====
  static const String appVersion = '4.0.0';

  // ===== COMUM =====
  static const String appName = 'app_name';
  static const String ok = 'common.ok';
  static const String cancel = 'common.cancel';
  static const String save = 'common.save';
  static const String delete = 'common.delete';
  static const String remove = 'common.remove';
  static const String edit = 'common.edit';
  static const String search = 'common.search';
  static const String loading = 'common.loading';
  static const String error = 'common.error';
  static const String success = 'common.success';
  static const String or = 'common.or';
  static const String close = 'common.close';
  static const String home = 'common.home';
  static const String traveling = 'common.traveling';

  // Datas
  static const String startsIn = 'common.starts_in';
  static const String daysTrip = 'common.days_trip';

  // Meses abreviados
  static const String jan = 'common.months.jan';
  static const String feb = 'common.months.feb';
  static const String mar = 'common.months.mar';
  static const String apr = 'common.months.apr';
  static const String may = 'common.months.may';
  static const String jun = 'common.months.jun';
  static const String jul = 'common.months.jul';
  static const String aug = 'common.months.aug';
  static const String sep = 'common.months.sep';
  static const String oct = 'common.months.oct';
  static const String nov = 'common.months.nov';
  static const String dec = 'common.months.dec';

  // Dias da semana
  static const String monday = 'common.days.monday';
  static const String tuesday = 'common.days.tuesday';
  static const String wednesday = 'common.days.wednesday';
  static const String thursday = 'common.days.thursday';
  static const String friday = 'common.days.friday';
  static const String saturday = 'common.days.saturday';
  static const String sunday = 'common.days.sunday';

  // ===== AUTENTICAÇÃO =====
  static const String welcomeBack = 'auth.welcome_back';
  static const String emailOrUsername = 'auth.email_or_username';
  static const String password = 'auth.password';
  static const String forgotPassword = 'auth.forgot_password';
  static const String login = 'auth.login';
  static const String continueWithGoogle = 'auth.continue_with_google';
  static const String dontHaveAccount = 'auth.dont_have_account';
  static const String noAccount = 'auth.no_account';
  static const String createAccount = 'auth.create_account';
  static const String alreadyHaveAccount = 'auth.already_have_account';
  static const String signIn = 'auth.sign_in';
  static const String authChooseMethod = 'auth.choose_how_to_create';
  static const String signInViaGoogle = 'auth.sign_in_via_google';
  static const String continueWithApple = 'auth.continue_with_apple';
  static const String signInViaApple = 'auth.sign_in_via_apple';
  static const String signInViaEmailPassword = 'auth.sign_in_via_email_password';
  static const String chooseHowToCreate = 'auth.choose_how_to_create';
  static const String fullName = 'auth.full_name';
  static const String username = 'auth.username';
  static const String phone = 'auth.phone';
  static const String phoneOptional = 'auth.phone_optional';
  static const String fillYourData = 'auth.fill_your_data';
  static const String accountCreatedSuccess = 'auth.account_created_success';
  static const String loginSuccess = 'auth.login_success';
  static const String accountExists = 'auth.account_exists';
  static const String existingAccount = 'auth.existing_account';
  static const String goToLogin = 'auth.go_to_login';
  static const String emailAlreadyRegistered = 'auth.email_already_registered';
  static const String verifyEmail = 'auth.verify_email';
  static const String checkEmailToActivate = 'auth.check_email_to_activate';
  static const String email = 'auth.email';
  static const String forgotPasswordTitle = 'auth.forgot_password_title';
  static const String emailSentTitle = 'auth.email_sent_title';
  static const String emailSentDescription = 'auth.email_sent_description';
  static const String forgotPasswordDescription = 'auth.forgot_password_description';
  static const String sendEmail = 'auth.send_email';
  static const String backToLogin = 'auth.back_to_login';
  static const String didntReceiveResend = 'auth.didnt_receive_resend';

  // Validações
  static const String emailRequired = 'auth.validation.email_required';
  static const String emailInvalid = 'auth.validation.email_invalid';
  static const String passwordRequired = 'auth.validation.password_required';
  static const String passwordMin6 = 'auth.validation.password_min_6';
  static const String nameRequired = 'auth.validation.name_required';
  static const String usernameRequired = 'auth.validation.username_required';

  // ===== HOME =====
  static const String homeTitle = 'home.title';
  static const String whereToNext = 'home.where_to_next';
  static const String searchDestinations = 'home.search_destinations';
  static const String upcomingTrips = 'home.upcoming_trips';
  static const String noUpcomingTrips = 'home.no_upcoming_trips';
  static const String startPlanningTrip = 'home.start_planning_trip';

  // ===== VIAGENS =====
  static const String trips = 'trips.title';
  static const String myTrips = 'trips.my_trips';
  static const String upcoming = 'trips.upcoming';
  static const String past = 'trips.past';
  static const String noTripsYet = 'trips.no_trips_yet';
  static const String createYourFirstTrip = 'trips.create_your_first_trip';
  static const String newTrip = 'trips.new_trip';
  static const String importTrip = 'trips.import_trip';
  static const String importTripTitle = 'trips.import_trip_title';
  static const String importSharedTrip = 'trips.import_shared_trip';
  static const String importTripDescription = 'trips.import_trip_description';
  static const String selectTriplanFile = 'trips.select_triplan_file';
  static const String codeLabel = 'trips.code_label';
  static const String searchByCode = 'trips.search_by_code';
  static const String enterCodePrompt = 'trips.enter_code_prompt';
  static const String fileSelected = 'trips.file_selected';
  static const String archiveSelected = 'trips.archive_selected';
  static const String preview = 'trips.preview';
  static const String howItWorks = 'trips.how_it_works';
  static const String importInstructions = 'trips.import_instructions';
  static const String errorReadingFile = 'trips.error_reading_file';
  static const String errorImportingTrip = 'trips.error_importing_trip';
  static const String fileInvalidOrCorrupted = 'trips.file_invalid_or_corrupted';
  static const String fileFormatInvalid = 'trips.file_format_invalid';
  static const String tripImportedSuccess = 'trips.trip_imported_success';
  static const String untitled = 'trips.untitled';
  static const String itinerariesDays = 'trips.itineraries_days';
  static const String travelersCount = 'trips.travelers_count';
  static const String codeHint = 'trips.code_hint';
  static const String addedToDay = 'trips.added_to_day';
  static const String errorAddingLocation = 'trips.error_adding_location';
  static const String tripTo = 'trips.trip_to';
  static const String days = 'trips.days';
  static const String day = 'trips.day';
  static const String dayLabel = 'trips.day_label';
  static const String noPastTrips = 'trips.no_past_trips';
  static const String noPastTripsSubtitle = 'trips.no_past_trips_subtitle';

  // ===== NOVA VIAGEM =====
  static const String planYourTrip = 'new_trip.plan_your_trip';
  static const String destination = 'new_trip.destination';
  static const String selectDestination = 'new_trip.select_destination';
  static const String startDate = 'new_trip.start_date';
  static const String endDate = 'new_trip.end_date';
  static const String tripTitle = 'new_trip.trip_title';
  static const String tripTitleExample = 'new_trip.trip_title_example';
  static const String description = 'new_trip.description';
  static const String descriptionOptional = 'new_trip.description_optional';
  static const String budget = 'new_trip.budget';
  static const String budgetOptional = 'new_trip.budget_optional';
  static const String numberOfTravelers = 'new_trip.number_of_travelers';
  static const String travelers = 'new_trip.travelers';
  static const String createTrip = 'new_trip.create_trip';
  static const String updateTrip = 'new_trip.update_trip';
  static const String yourNextTrip = 'new_trip.your_next_trip';
  static const String editYourTrip = 'new_trip.edit_your_trip';
  static const String toCountryOrCity = 'new_trip.to_country_or_city';
  static const String pickDates = 'new_trip.pick_dates';
  static const String startPlanning = 'new_trip.start_planning';
  static const String saveChanges = 'new_trip.save_changes';
  static const String errorCreatingTrip = 'new_trip.error_creating_trip';
  static const String errorUpdatingTrip = 'new_trip.error_updating_trip';

  // ===== DETALHES DA VIAGEM =====
  static const String overview = 'trip_details.overview';
  static const String itinerary = 'trip_details.itinerary';
  static const String map = 'trip_details.map';
  static const String activities = 'trip_details.activities';
  static const String noActivitiesYet = 'trip_details.no_activities_yet';
  static const String addActivity = 'trip_details.add_activity';
  static const String addAnotherActivity = 'trip_details.add_another_activity';
  static const String startingPoint = 'trip_details.starting_point';
  static const String getDirections = 'trip_details.get_directions';
  static const String directions = 'trip_details.directions';
  static const String navigation = 'trip_details.navigation';
  static const String transportMode = 'trip_details.transport_mode';
  static const String transportModeUpdated = 'trip_details.transport_mode_updated';
  static const String walking = 'trip_details.transport.walking';
  static const String driving = 'trip_details.transport.driving';
  static const String transit = 'trip_details.transport.transit';
  static const String bicycling = 'trip_details.transport.bicycling';
  static const String minutes = 'trip_details.minutes';
  static const String hours = 'trip_details.hours';
  static const String hoursNotListed = 'trip_details.hours_not_listed';
  static const String myTrip = 'trip_details.my_trip';
  static const String yourRoute = 'trip_details.your_route';
  static const String shareTrip = 'trip_details.share_trip';
  static const String shareTripSubtitle = 'trip_details.share_trip_subtitle';
  static const String editTrip = 'trip_details.edit_trip';
  static const String editTime = 'trip_details.edit_time';
  static const String deleteTrip = 'trip_details.delete_trip';
  static const String deleteTripSubtitle = 'trip_details.delete_trip_subtitle';
  static const String deleteTripTitle = 'trip_details.delete_trip_title';
  static const String deleteTripMessage = 'trip_details.delete_trip_message';
  static const String tripDeletedSuccess = 'trip_details.trip_deleted_success';
  static const String errorDeletingTrip = 'trip_details.error_deleting_trip';
  static const String removePlace = 'trip_details.remove_place';
  static const String startPlanningDay = 'trip_details.start_planning_day';
  static const String departureAirport = 'trip_details.departure_airport';
  static const String nearestAirport = 'trip_details.nearest_airport';
  static const String arrivalAirport = 'trip_details.arrival_airport';
  static const String destinationAirport = 'trip_details.destination_airport';
  static const String retry = 'trip_details.retry';
  static const String closedAtRequestedTime = 'trip_details.closed_at_requested_time';
  static const String pressAndHoldToMove = 'trip_details.press_and_hold_to_move';
  static const String maxItemsPerDay = 'trip_details.max_items_per_day';
  static const String maxItemsReached = 'trip_details.max_items_reached';
  static const String chooseDayMessage = 'trip_details.choose_day_message';
  static const String startTime = 'trip_details.start_time';
  static const String duration = 'trip_details.duration';
  static const String current = 'trip_details.current';
  static const String moveToAnotherDay = 'trip_details.move_to_another_day';
  static const String duplicateFavoriteMessage = 'trip_details.duplicate_favorite_message';
  static const String placeMovedToDay = 'trip_details.place_moved_to_day';
  static const String couldNotOpenMaps = 'trip_details.could_not_open_maps';
  static const String errorOpeningMaps = 'trip_details.error_opening_maps';

  // Mensagens de sucesso/erro
  static const String timeUpdatedSuccess = 'trip_details.time_updated_success';
  static const String transportUpdatedSuccess = 'trip_details.transport_updated_success';
  static const String placeRemovedSuccess = 'trip_details.place_removed_success';
  static const String errorUpdatingTime = 'trip_details.error_updating_time';
  static const String errorUpdatingTransport = 'trip_details.error_updating_transport';
  static const String errorRemovingPlace = 'trip_details.error_removing_place';
  static const String errorMovingPlace = 'trip_details.error_moving_place';
  static const String errorReordering = 'trip_details.error_reordering';
  static const String errorSharingTrip = 'trip_details.error_sharing_trip';
  static const String generateShareCodeTitle = 'trip_details.generate_share_code_title';
  static const String generateShareCodeSubtitle = 'trip_details.generate_share_code_subtitle';
  static const String shareCodeDialogTitle = 'trip_details.share_code_dialog_title';
  static const String shareCodeLabel = 'trip_details.share_code_label';
  static const String copy = 'trip_details.copy';
  static const String codeCopied = 'trip_details.code_copied';

  // Favorites
  static const String addToFavorites = 'trip_details.add_to_favorites';
  static const String noPlacesToFavorite = 'trip_details.no_places_to_favorite';
  static const String addedToFavorites = 'trip_details.added_to_favorites';
  static const String errorAddingFavorite = 'trip_details.error_adding_favorite';
  static const String favorites = 'favorites.title';
  static const String myFavorites = 'favorites.my_favorites';
  static const String noFavorites = 'favorites.no_favorites';
  static const String noFavoritesDescription = 'favorites.no_favorites_description';
  static const String removeFavorite = 'favorites.remove_favorite';
  static const String removedFromFavorites = 'favorites.removed_from_favorites';
  static const String errorRemovingFavorite = 'favorites.error_removing_favorite';

  // ===== MAPA =====
  static const String showRoute = 'map.show_route';
  static const String hideRoute = 'map.hide_route';
  static const String yourLocation = 'map.your_location';
  static const String origin = 'map.origin';
  static const String destination_map = 'map.destination';

  // ===== PERFIL =====
  static const String profile = 'profile.title';
  static const String settings = 'profile.settings';
  static const String language = 'profile.language';
  static const String theme = 'profile.theme';
  static const String themeLight = 'profile.theme_light';
  static const String themeDark = 'profile.theme_dark';
  static const String themeSystem = 'profile.theme_system';
  static const String logout = 'profile.logout';
  static const String logoutSubtitle = 'profile.logout_subtitle';
  static const String logoutConfirm = 'profile.logout_confirm';
  static const String exit = 'profile.exit';
  static const String account = 'profile.account';
  static const String about = 'profile.about';
  static const String aboutTriplanAI = 'profile.about_triplanai';
  static const String aboutDescription = 'profile.about_description';
  static const String copyright = 'profile.copyright';
  static const String version = 'profile.version';
  static const String notifications = 'profile.notifications';
  static const String notificationsSubtitle = 'profile.notifications_subtitle';
  static const String privacy = 'profile.privacy';
  static const String privacySubtitle = 'profile.privacy_subtitle';
  static const String privacyPolicyUrl = 'https://redadviser.com/?page_id=316';
  static const String helpSupport = 'profile.help_support';
  static const String faqs = 'profile.faqs';
  static const String faqsSubtitle = 'profile.faqs_subtitle';
  static const String contactSupport = 'profile.contact_support';
  static const String contactSupportSubtitle = 'profile.contact_support_subtitle';
  static const String chooseFromGallery = 'profile.choose_from_gallery';
  static const String takePhoto = 'profile.take_photo';
  static const String removePhoto = 'profile.remove_photo';
  static const String inDevelopment = 'profile.in_development';
  static const String faqQuestion1 = 'profile.faq_question_1';
  static const String faqAnswer1 = 'profile.faq_answer_1';
  static const String faqQuestion2 = 'profile.faq_question_2';
  static const String faqAnswer2 = 'profile.faq_answer_2';
  static const String faqQuestion3 = 'profile.faq_question_3';
  static const String faqAnswer3 = 'profile.faq_answer_3';
  static const String faqQuestion4 = 'profile.faq_question_4';
  static const String faqAnswer4 = 'profile.faq_answer_4';
  static const String faqQuestion5 = 'profile.faq_question_5';
  static const String faqAnswer5 = 'profile.faq_answer_5';
  static const String faqQuestion6 = 'profile.faq_question_6';
  static const String faqAnswer6 = 'profile.faq_answer_6';
  static const String faqQuestion7 = 'profile.faq_question_7';
  static const String faqAnswer7 = 'profile.faq_answer_7';
  static const String faqQuestion8 = 'profile.faq_question_8';
  static const String faqAnswer8 = 'profile.faq_answer_8';
  static const String faqQuestion9 = 'profile.faq_question_9';
  static const String faqAnswer9 = 'profile.faq_answer_9';
  static const String faqQuestion10 = 'profile.faq_question_10';
  static const String faqAnswer10 = 'profile.faq_answer_10';
  static const String requestDelete = 'profile.request_delete';
  static const String deleteRequestSent = 'profile.delete_request_sent';
  static const String deleteAccount = 'profile.delete_account';
  static const String deleteAccountSubtitle = 'profile.delete_account_subtitle';
  static const String deleteAccountMessage = 'profile.delete_message';
  static const String notificationsEnabled = 'profile.notifications_enabled';
  static const String notificationsDisabled = 'profile.notifications_disabled';
  static const String testNotificationSent = 'profile.test_notification_sent';
  static const String appleRegisterError = 'auth.apple_register_error';
  static const String onlyTriplanSupported = 'trips.only_triplan_supported';
  static const String importingTrip = 'trips.importing_trip';
  static const String confirmRemoveFavorite = 'favorites.confirm_remove_favorite';

  // ===== IDIOMAS =====
  static const String portuguese = 'languages.portuguese';
  static const String english = 'languages.english';
  static const String spanish = 'languages.spanish';
  static const String french = 'languages.french';
  static const String german = 'languages.german';
  static const String italian = 'languages.italian';
  static const String chinese = 'languages.chinese';
  static const String japanese = 'languages.japanese';
  static const String korean = 'languages.korean';

  // ===== MENSAGENS DE ERRO =====
  static const String errorConnection = 'errors.connection';
  static const String errorGeneric = 'errors.generic';
  static const String errorTimeout = 'errors.timeout';
  static const String errorNotFound = 'errors.not_found';
  static const String tripAlreadyOwned = 'trips.already_owned';
  static const String tripAlreadyImported = 'trips.already_imported';

  // ===== PESQUISA =====
  static const String searchPlaces = 'search.search_places';
  static const String searchResults = 'search.search_results';
  static const String noResults = 'search.no_results';
  static const String tryDifferentSearch = 'search.try_different_search';

  // ===== PREMIUM =====
  static const String premium = 'premium.title';
  static const String activatePremium = 'premium.activate_premium';
  static const String activatePremiumSubtitle = 'premium.activate_premium_subtitle';
  static const String upgradeToPremium = 'premium.upgrade_to_premium';
  static const String premiumFeatures = 'premium.premium_features';
  static const String premiumActive = 'premium.premium_active';
  static const String premiumExpires = 'premium.premium_expires';
  static const String premiumExpired = 'premium.premium_expired';
  static const String unlimitedTrips = 'premium.unlimited_trips';
  static const String aiSuggestions = 'premium.ai_suggestions';
  static const String prioritySupport = 'premium.priority_support';
  static const String offlineMode = 'premium.offline_mode';
  static const String subscribeContinue = 'premium.subscribe_continue';
  static const String restorePurchases = 'premium.restore_purchases';
  static const String alreadyPremium = 'premium.already_premium';
  static const String purchaseSuccessful = 'premium.purchase_successful';
  static const String purchaseFailed = 'premium.purchase_failed';
  static const String purchaseRestored = 'premium.purchase_restored';
  static const String purchasesRestored = 'premium.purchases_restored';
  static const String noPurchasesToRestore = 'premium.no_purchases_to_restore';
  static const String restoreFailed = 'premium.restore_failed';
  static const String monthly = 'premium.monthly';
  static const String yearly = 'premium.yearly';
  static const String perMonth = 'premium.per_month';
  static const String perYear = 'premium.per_year';
  static const String savePremium = 'premium.save';
  static const String mostPopular = 'premium.most_popular';

  // ===== LIMITS =====
  static const String tripLimitTitle = 'limits.trip_limit_title';
  static const String tripLimitDesc = 'limits.trip_limit_desc';
  static const String activityLimitTitle = 'limits.activity_limit_title';
  static const String activityLimitDesc = 'limits.activity_limit_desc';
  static const String aiLimitTitle = 'limits.ai_limit_title';
  static const String aiLimitDesc = 'limits.ai_limit_desc';
  static const String pdfLockedTitle = 'limits.pdf_locked_title';
  static const String pdfLockedDesc = 'limits.pdf_locked_desc';
  static const String backupLockedTitle = 'limits.backup_locked_title';
  static const String backupLockedDesc = 'limits.backup_locked_desc';
  static const String maybeLater = 'limits.maybe_later';
  static const String upgradeNow = 'limits.upgrade_now';

  // ===== AI CHAT =====
  static const String aiChatDayHeader = 'ai_chat.day_header';
  static const String aiChatLoadingConversation = 'ai_chat.loading_conversation';
  static const String aiChatWelcome = 'ai_chat.welcome';
  static const String aiChatSuggestionExample = 'ai_chat.suggestion_example';
  static const String aiChatFallbackResponse = 'ai_chat.fallback_response';
  static const String aiChatErrorResponse = 'ai_chat.error_response';
  static const String aiChatPlaceNotFound = 'ai_chat.place_not_found';
  static const String aiChatInputHint = 'ai_chat.input_hint';
  static const String aiChatAddYourSpot = 'ai_chat.add_your_spot';
  static const String aiChatDefaultDescription = 'ai_chat.default_description';
  static const String aiChatAddressNotAvailable = 'ai_chat.address_not_available';
  static const String aiChatHoursNotAvailable = 'ai_chat.hours_not_available';
  static const String aiChatAddToPlan = 'ai_chat.add_to_plan';

  // ===== NOTES =====
  static const String notesTitle = 'notes.title';
  static const String notesNewNote = 'notes.new_note';
  static const String notesNoNotes = 'notes.no_notes';
  static const String notesCreateOne = 'notes.create_one';
  static const String notesUntitled = 'notes.untitled';
  static const String notesDeleteConfirm = 'notes.delete_confirm';
  static const String notesDeleteMessage = 'notes.delete_message';
  static const String notesNotePlaceholder = 'notes.note_placeholder';
  static const String notesSave = 'notes.save';
}
