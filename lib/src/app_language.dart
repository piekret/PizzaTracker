import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _languagePreferenceKey = 'app_language_code';

final initialAppLanguageProvider = Provider<AppLanguage>((ref) {
  return AppLanguage.english;
});

final appLanguageProvider =
    NotifierProvider<AppLanguageController, AppLanguage>(
      AppLanguageController.new,
    );

enum AppLanguage {
  english('en', 'English', 'EN'),
  polish('pl', 'Polski', 'PL');

  const AppLanguage(this.code, this.label, this.shortLabel);

  final String code;
  final String label;
  final String shortLabel;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) {
    return switch (code?.trim().toLowerCase()) {
      'pl' => AppLanguage.polish,
      _ => AppLanguage.english,
    };
  }
}

class AppLanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => ref.watch(initialAppLanguageProvider);

  Future<void> select(AppLanguage language) async {
    if (state == language) {
      return;
    }
    state = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePreferenceKey, language.code);
  }
}

Future<AppLanguage> loadInitialAppLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  return AppLanguage.fromCode(prefs.getString(_languagePreferenceKey));
}

extension AppLanguageContext on BuildContext {
  AppText get text => AppText.of(this);
}

class AppText {
  const AppText(this.appLanguage);

  final AppLanguage appLanguage;

  static AppText of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return AppText(AppLanguage.fromCode(locale.languageCode));
  }

  bool get isPolish => appLanguage == AppLanguage.polish;

  String get appTitle => 'PizzaTracker';
  String get language => isPolish ? 'Język' : 'Language';
  String get theme => isPolish ? 'Motyw' : 'Theme';
  String get back => isPolish ? 'Wstecz' : 'Back';
  String get cancel => isPolish ? 'Anuluj' : 'Cancel';
  String get delete => isPolish ? 'Usuń' : 'Delete';
  String get save => isPolish ? 'Zapisz' : 'Save';
  String get add => isPolish ? 'Dodaj' : 'Add';
  String get edit => isPolish ? 'Edytuj' : 'Edit';
  String get name => isPolish ? 'Nazwa' : 'Name';
  String get amount => isPolish ? 'Kwota' : 'Amount';
  String get category => isPolish ? 'Kategoria' : 'Category';
  String get date => isPolish ? 'Data' : 'Date';
  String get all => isPolish ? 'Wszystkie' : 'All';
  String get other => isPolish ? 'Inne' : 'Other';
  String get addReceipt => isPolish ? 'Dodaj paragon' : 'Add receipt';
  String get addExpense => isPolish ? 'Dodaj wydatek' : 'Add expense';
  String get scanReceipt => isPolish ? 'Skanuj paragon' : 'Scan receipt';
  String get signOut => isPolish ? 'Wyloguj' : 'Sign out';
  String get loadingProfile =>
      isPolish ? 'Ładowanie profilu...' : 'Loading profile...';
  String get loadingSummary =>
      isPolish ? 'Ładowanie podsumowania...' : 'Loading summary...';
  String get loadingExpenses =>
      isPolish ? 'Ładowanie wydatków...' : 'Loading expenses...';
  String get loadingExpenseHistory => isPolish
      ? 'Ładowanie historii wydatków...'
      : 'Loading expense history...';
  String get calculatingDesperation => isPolish
      ? 'Liczenie Indeksu Desperacji...'
      : 'Calculating desperation...';
  String get desperationIndex =>
      isPolish ? 'Indeks Desperacji' : 'Desperation Index';
  String get remaining => isPolish ? 'Pozostało' : 'Remaining';
  String get daysLeft => isPolish ? 'Dni do końca' : 'Days left';
  String get dailyLimit => isPolish ? 'Limit dzienny' : 'Daily limit';
  String get spent => isPolish ? 'Wydano' : 'Spent';
  String get receipts => isPolish ? 'Paragony' : 'Receipts';
  String get spendingMix => isPolish ? 'Struktura wydatków' : 'Spending mix';
  String get recentExpenses =>
      isPolish ? 'Ostatnie wydatki' : 'Recent expenses';
  String get fixedMonthlyCosts =>
      isPolish ? 'Stałe koszty miesięczne' : 'Fixed monthly costs';
  String get expectedIncome =>
      isPolish ? 'Oczekiwane wpływy' : 'Expected income';
  String get monthlyBudgetLockedIn =>
      isPolish ? 'Budżet miesięczny ustawiony' : 'Monthly budget locked in';
  String get expenseHistory =>
      isPolish ? 'Historia wydatków' : 'Expense history';
  String get searchExpenses => isPolish ? 'Szukaj wydatków' : 'Search expenses';
  String get noExpensesYet =>
      isPolish ? 'Nie ma jeszcze wydatków' : 'No expenses yet';
  String get noMatchingExpenses =>
      isPolish ? 'Brak pasujących wydatków' : 'No matching expenses';
  String get tryDifferentSearch => isPolish
      ? 'Spróbuj innego wyszukiwania albo kategorii.'
      : 'Try a different search or category.';
  String get addFirstExpense => isPolish
      ? 'Dodaj pierwszy wydatek, żeby zacząć rejestr.'
      : 'Add your first expense to start the ledger.';
  String get deleteExpenseQuestion =>
      isPolish ? 'Usunąć wydatek?' : 'Delete expense?';
  String removeExpenseFromHistory(String name) => isPolish
      ? 'Usunąć $name z historii budżetu?'
      : 'Remove $name from your budget history?';
  String expenseCount(int count) => isPolish
      ? '$count ${count == 1
            ? 'wydatek'
            : count < 5
            ? 'wydatki'
            : 'wydatków'}'
      : count == 1
      ? '1 expense'
      : '$count expenses';
  String get manualEntry => isPolish ? 'Ręczne dodawanie' : 'Manual entry';
  String get receiptAutofill =>
      isPolish ? 'Autouzupełnienie z paragonu' : 'Receipt autofill';
  String get reviewExtractedExpense =>
      isPolish ? 'Sprawdź odczytany wydatek' : 'Review extracted expense';
  String get editExpense => isPolish ? 'Edytuj wydatek' : 'Edit expense';
  String get expenseSaved => isPolish ? 'Wydatek zapisany.' : 'Expense saved.';
  String get expenseUpdated =>
      isPolish ? 'Wydatek zaktualizowany.' : 'Expense updated.';
  String get saveChanges => isPolish ? 'Zapisz zmiany' : 'Save changes';
  String get saveExpense => isPolish ? 'Zapisz wydatek' : 'Save expense';
  String get nameRequired =>
      isPolish ? 'Nazwa jest wymagana.' : 'Name is required.';
  String get enterAmountAboveZero =>
      isPolish ? 'Podaj kwotę większą od 0.' : 'Enter an amount above 0.';
  String get useDayFrom1To28 =>
      isPolish ? 'Użyj dnia od 1 do 28.' : 'Use a day from 1 to 28.';
  String get receiptUpload =>
      isPolish ? 'Dodawanie paragonu' : 'Receipt upload';
  String get takePhoto => isPolish ? 'Zrób zdjęcie' : 'Take photo';
  String get chooseFromGallery =>
      isPolish ? 'Wybierz z galerii' : 'Choose from gallery';
  String get uploadingReceipt => isPolish
      ? 'Wysyłanie i odczytywanie paragonu...'
      : 'Uploading and reading receipt...';
  String get receiptUploadDescription => isPolish
      ? 'Najpierw działa lokalny OCR, potem AI zamienia tekst paragonu w sugestie wydatków.'
      : 'Runs local OCR first, then uses AI to turn receipt text into expense suggestions.';
  String get receiptReview =>
      isPolish ? 'Sprawdzenie paragonu' : 'Receipt review';
  String get reviewReceiptItems =>
      isPolish ? 'Sprawdź pozycje z paragonu' : 'Review receipt items';
  String get addMissingItem =>
      isPolish ? 'Dodaj brakującą pozycję' : 'Add missing item';
  String get removeItem => isPolish ? 'Usuń pozycję' : 'Remove item';
  String itemNumber(int index) =>
      isPolish ? 'Pozycja ${index + 1}' : 'Item ${index + 1}';
  String confidence(int percent) =>
      isPolish ? '$percent% pewności' : '$percent% confidence';
  String receiptTotal(String total) =>
      isPolish ? 'Suma paragonu: $total' : 'Receipt total: $total';
  String lineItemsReviewTotal(String total) =>
      isPolish ? 'Pozycje: $total' : 'Items: $total';
  String lineItemsTotal(String itemsTotal, String receiptTotal) => isPolish
      ? 'Suma pozycji to $itemsTotal, a paragon pokazuje $receiptTotal. Sprawdź, czy czegoś nie brakuje albo czy OCR nie odczytał ceny źle.'
      : 'Line items total $itemsTotal, but the receipt shows $receiptTotal. Check for a missing item or an OCR price mistake.';
  String get receiptTotalsCheck =>
      isPolish ? 'Kontrola paragonu' : 'Receipt check';
  String saveExpenseCount(int count) => isPolish
      ? count == 1
            ? 'Zapisz 1 wydatek'
            : 'Zapisz $count wydatków'
      : count == 1
      ? 'Save 1 expense'
      : 'Save $count expenses';
  String get receiptSavedDesperationUpdated => isPolish
      ? 'Paragon zapisany. Indeks Desperacji zaktualizowany.'
      : 'Receipt saved. Desperation Index updated.';
  String get receiptReviewHint => isPolish
      ? 'Sprawdź nazwy, kwoty, kategorie i datę przed zapisem. Zostaną dodane jako osobne wydatki powiązane z tym paragonem.'
      : 'Check names, amounts, categories, and date before saving. These will become separate expense rows tied to this receipt.';
  String get statsSnapshot => isPolish ? 'Migawka statystyk' : 'Stats snapshot';
  String get financialCharts =>
      isPolish ? 'Wykresy finansowych głupot' : 'Financial stupidity charts';
  String get monthlyPulse => isPolish ? 'Puls miesiąca' : 'Monthly pulse';
  String get budgetStory => isPolish ? 'Historia budżetu' : 'Budget story';
  String get thisMonthInOneGlance =>
      isPolish ? 'Ten miesiąc jednym rzutem oka' : 'This month in one glance';
  String get thisMonth => isPolish ? 'Ten miesiąc' : 'This month';
  String get aiInsights => isPolish ? 'Insight AI' : 'AI insights';
  String get generateInsights =>
      isPolish ? 'Wygeneruj insighty' : 'Generate insights';
  String get refreshInsights =>
      isPolish ? 'Odśwież insighty' : 'Refresh insights';
  String get cachedResult => isPolish ? 'Wynik z cache' : 'Cached result';
  String get generatingInsights =>
      isPolish ? 'Generowanie insightów...' : 'Generating insights...';
  String get loadingDailyTotals =>
      isPolish ? 'Ładowanie dziennych sum...' : 'Loading daily totals...';
  String get loadingCategoryTotals => isPolish
      ? 'Ładowanie sum według kategorii...'
      : 'Loading category totals...';
  String get emergencyRecipes =>
      isPolish ? 'Awaryjne przepisy' : 'Emergency recipes';
  String get whatToCook => isPolish ? 'Co ugotować' : 'What to cook';
  String get yourPantry => isPolish ? 'Twoja spiżarnia' : 'Your pantry';
  String get addIngredient => isPolish ? 'Dodaj składnik' : 'Add ingredient';
  String get generateRecipes =>
      isPolish ? 'Generuj przepisy' : 'Generate recipes';
  String get recipesLocked => isPolish
      ? 'Przepisy odblokują się przy Indeksie Desperacji 60/100.'
      : 'Recipes unlock at Desperation Index 60/100.';
  String get locked => isPolish ? 'Zablokowane' : 'Locked';
  String get setupKicker =>
      isPolish ? 'Brak lokalnej konfiguracji' : 'Local config missing';
  String get setupTitle =>
      isPolish ? 'Konfiguracja PizzaTracker' : 'PizzaTracker setup';
  String get setupBody => isPolish
      ? 'Flutter czyta bezpieczne dla klienta wartości Supabase najpierw z dart-defines, potem z wygenerowanego zasobu assets/env/client.env. Klucze OpenAI, service-role, Firebase admin i hasła bazy trzymaj tylko w .env.'
      : 'Flutter reads client-safe Supabase values from dart-defines first, then the generated assets/env/client.env asset. Keep OpenAI, service-role, Firebase admin, and database secrets in .env only.';
  String get setupHint => isPolish
      ? 'Jeśli ten ekran nadal jest widoczny, uzupełnij .env wartościami SUPABASE_URL i SUPABASE_ANON_KEY, uruchom skrypt synchronizacji i włącz Flutter ponownie.'
      : 'If this screen stays visible, fill .env with SUPABASE_URL plus SUPABASE_ANON_KEY, run the sync script, then start Flutter again.';
  String get authTagline => isPolish
      ? 'Studencki zestaw przetrwania budżetowego'
      : 'Student budget survival kit';
  String get canIAffordThis =>
      isPolish ? 'Czy mnie na to stać?' : 'Can I afford this?';
  String get authHeroShort => isPolish
      ? 'Wiedz, czy dziś jest wieczór pizzy, czy kontrola szkód makaronem.'
      : 'Know if tonight is pizza night or pasta damage control.';
  String get authHeroLong => isPolish
      ? 'Wiedz, czy dziś jest wieczór pizzy, czy kontrola szkód makaronem, zanim konto zacznie negocjować.'
      : 'Know if tonight is pizza night or pasta damage control before your bank account starts negotiating.';
  String get receiptsBecomeExpenses =>
      isPolish ? 'Paragony stają się wydatkami' : 'Receipts become expenses';
  String get manualNowOcrNext =>
      isPolish ? 'Ręcznie teraz, OCR zaraz.' : 'Manual now, OCR next.';
  String get oneBrutalNumber => isPolish
      ? 'Jedna brutalna liczba na resztę miesiąca.'
      : 'One brutal number for the rest of the month.';
  String get recipesLater => isPolish ? 'Przepisy później' : 'Recipes later';
  String get whenBudgetGetsUgly => isPolish
      ? 'Kiedy budżet robi się brzydki.'
      : 'When the budget gets ugly.';
  String get offlineUnavailable => isPolish
      ? 'Jesteś w trybie offline. Dane z cache możesz przeglądać, ale zmian nie da się teraz zapisać. '
            'Połącz się z internetem i spróbuj ponownie.'
      : 'You are in offline mode. Cached data is available to view, but changes cannot be saved right now. '
            'Connect to the internet and try again.';

  String categoryLabel(String category) {
    return switch (category) {
      'food' => isPolish ? 'Jedzenie' : 'Food',
      'alcohol' => isPolish ? 'Alkohol' : 'Alcohol',
      'hygiene' => isPolish ? 'Higiena' : 'Hygiene',
      'fun' => isPolish ? 'Rozrywka' : 'Fun',
      _ => other,
    };
  }

  List<String> get ingredientSuggestions {
    return isPolish
        ? const [
            'makaron',
            'jajka',
            'cebula',
            'ryż',
            'fasola',
            'ser',
            'pomidor',
          ]
        : const ['pasta', 'eggs', 'onion', 'rice', 'beans', 'cheese', 'tomato'];
  }

  ({String label, String shortLabel}) levelText(int index) {
    if (index <= 20) {
      return (
        label: isPolish
            ? 'Jest dobrze. Pizza jest prawnie do obrony.'
            : 'All good. Pizza is legally defensible.',
        shortLabel: isPolish ? 'Jest dobrze' : 'All good',
      );
    }
    if (index <= 45) {
      return (
        label: isPolish
            ? 'Uważaj. Pizza tak, śniadanie nie.'
            : 'Watch out. Pizza yes, breakfast no.',
        shortLabel: isPolish ? 'Uważaj' : 'Watch out',
      );
    }
    if (index <= 70) {
      return (
        label: isPolish
            ? 'Tryb oszczędzania. Gotuj w domu.'
            : 'Economy mode. Cook at home.',
        shortLabel: isPolish ? 'Oszczędzanie' : 'Economy',
      );
    }
    if (index <= 90) {
      return (
        label: isPolish
            ? 'SOS. Zacznij liczyć porcje makaronu.'
            : 'SOS. Start counting pasta portions.',
        shortLabel: 'SOS',
      );
    }
    return (
      label: isPolish
          ? 'Apokalipsa. Sprawdź zamrażarkę.'
          : 'Apocalypse. Check the freezer.',
      shortLabel: isPolish ? 'Apokalipsa' : 'Apocalypse',
    );
  }

  String translateKnown(String value) {
    var normalized = value;
    final direct = isPolish ? _plKnown[value] : null;
    if (direct != null) {
      return direct;
    }

    for (final prefix in ['Bad state: ', 'Exception: ']) {
      if (normalized.startsWith(prefix)) {
        normalized = normalized.substring(prefix.length);
        if (_looksLikeOfflineError(normalized)) {
          return offlineUnavailable;
        }
        if (!isPolish) return normalized;
        final translated = _plKnown[normalized];
        if (translated != null) {
          return translated;
        }
      }
    }

    if (_looksLikeOfflineError(normalized)) {
      return offlineUnavailable;
    }

    if (!isPolish) return normalized;
    return normalized;
  }
}

bool _looksLikeOfflineError(String value) {
  final normalized = value.toLowerCase();
  return normalized.contains('socketexception') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('failed to fetch') ||
      normalized.contains('xmlhttprequest error') ||
      normalized.contains('networkerror') ||
      normalized.contains('network is unreachable') ||
      normalized.contains('no address associated with hostname') ||
      normalized.contains('nodename nor servname') ||
      normalized.contains('no route to host') ||
      normalized.contains('connection timed out') ||
      normalized.contains('connection timeout') ||
      normalized.contains('connection refused') ||
      normalized.contains('connection reset') ||
      normalized.contains('connection closed before full header') ||
      normalized.contains('software caused connection abort') ||
      normalized.contains('the internet connection appears to be offline') ||
      normalized.contains('clientexception with socketexception');
}

const _plKnown = <String, String>{
  'Loading fixed costs...': 'Ładowanie stałych kosztów...',
  'Loading income schedule...': 'Ładowanie planu wpływów...',
  'Loading spending mix...': 'Ładowanie struktury wydatków...',
  'Loading recent expenses...': 'Ładowanie ostatnich wydatków...',
  'Loading daily totals...': 'Ładowanie dziennych sum...',
  'Loading category totals...': 'Ładowanie sum według kategorii...',
  'Generating insights...': 'Generowanie insightów...',
  'Cached result': 'Wynik z cache',
  'Pull to refresh or try again in a moment.':
      'Odśwież ekran albo spróbuj ponownie za chwilę.',
  'Pull to refresh. If this keeps happening, check your profile and budget data.':
      'Odśwież ekran. Jeśli problem wraca, sprawdź profil i dane budżetu.',
  'Can I afford this?': 'Czy mnie na to stać?',
  'Financial stupidity charts': 'Wykresy finansowych głupot',
  'See categories, spending pace, and the days that hit hardest.':
      'Zobacz kategorie, tempo wydatków i dni, które najbardziej bolały.',
  'Emergency recipes': 'Awaryjne przepisy',
  'Unlock recipes when the budget starts looking grim.':
      'Odblokuj przepisy, kiedy budżet zaczyna wyglądać ponuro.',
  'Monthly budget locked in': 'Budżet miesięczny ustawiony',
  'Fixed monthly costs': 'Stałe koszty miesięczne',
  'Expected income': 'Oczekiwane wpływy',
  'Filtered total': 'Suma filtrowana',
  'Full ledger': 'Pełny rejestr',
  'Receipt picker is unavailable. Fully restart the app, then try again.':
      'Wybór paragonu jest niedostępny. Uruchom aplikację ponownie i spróbuj jeszcze raz.',
  'Gemini quota is exhausted. Using local OCR only; check the fields before saving.':
      'Limit Gemini został wyczerpany. Używam tylko lokalnego OCR; sprawdź pola przed zapisem.',
  'Receipt uploaded. Manual entry is ready; deploy receipt analysis to enable autofill.':
      'Paragon wysłany. Ręczne dodawanie jest gotowe; wdroż analizę paragonów, aby włączyć autouzupełnianie.',
  'Receipt uploaded, but automatic reading is unavailable. Fill the expense manually.':
      'Paragon wysłany, ale automatyczny odczyt jest niedostępny. Uzupełnij wydatek ręcznie.',
  'Local OCR was unavailable, so receipt analysis used the uploaded image.':
      'Lokalny OCR był niedostępny, więc analiza paragonu użyła wysłanego obrazu.',
  'Receipt purchase': 'Zakup z paragonu',
  'Receipt has no OCR text or image': 'Paragon nie ma tekstu OCR ani obrazu',
  'Receipt not found.': 'Nie znaleziono paragonu.',
  'Receipt image path does not belong to current user.':
      'Ścieżka obrazu paragonu nie należy do aktualnego użytkownika.',
  'Recipe response missing recipes array.':
      'Odpowiedź z przepisami nie zawiera listy przepisów.',
  'At least two ingredients are required':
      'Wymagane są co najmniej dwa składniki',
  'Gemini response did not contain text output':
      'Odpowiedź Gemini nie zawierała tekstu',
  'Function environment is not configured':
      'Środowisko funkcji nie jest skonfigurowane',
  'Invalid month format. Use YYYY-MM.':
      'Niepoprawny format miesiąca. Użyj YYYY-MM.',
  'Add at least one receipt item.':
      'Dodaj co najmniej jedną pozycję z paragonu.',
  'You need to sign in first.': 'Najpierw musisz się zalogować.',
  'Email not confirmed': 'Email nie został jeszcze potwierdzony.',
  'Invalid login credentials': 'Nieprawidłowy email albo hasło.',
  'Unsupported currency. Choose one from the list.':
      'Nieobsługiwana waluta. Wybierz jedną z listy.',
  'Unexpected receipt analysis response.':
      'Nieoczekiwana odpowiedź analizy paragonu.',
  'Unsupported receipt image format. Use JPG, PNG, or WebP.':
      'Nieobsługiwany format obrazu paragonu. Użyj JPG, PNG albo WebP.',
  'No expenses recorded this month yet.':
      'W tym miesiącu nie zapisano jeszcze żadnych wydatków.',
};
