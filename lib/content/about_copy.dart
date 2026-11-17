// Short in-app copy for menu panes («О …», «Как искать»). Edit here after
// review; keep texts brief — full detail lives on the website.
// Bodies are HTML: use <p> and <a href="…">; opened in the system browser.

const String siteBaseUrl = "https://punzhina.krc.karelia.ru";
const String rightsHolderUrl = "https://www.krc.karelia.ru/";

const String aboutDictionaryTitle = "О словаре";

const String aboutDictionaryBody = """
<p>«Словарь карельского языка (тверские говоры)» составлен Александрой Васильевной Пунжиной и издан в 1994 году. Это основное лексикографическое издание по языку тверских карел.</p>
<p>Электронная версия включает авторские правки и дополнения составителя. Подробнее о словаре и составителе вы можете узнать на <a href="$siteBaseUrl/">сайте проекта</a>.</p>
""";

const String aboutAppTitle = "О приложении";

/// Body without the version line (version is shown separately from package_info).
const String aboutAppBody = """
<p>Офлайн-приложение это ограниченный клиент электронной версии словаря для работы без доступа в Интернет: алфавитный указатель, поиск по карельскому и русскому, карточки статей со ссылками «см.» / «от».</p>
<p>Расширенный поиск, онтология и актуальные обновления сайта здесь не дублируются, поэтому по возможности пользуйтесь <a href="$siteBaseUrl/">полной веб-версией</a>.</p>
""";

const String searchHelpTitle = "Как искать";

/// Offline-only: no web fuzzy, lemmas, or ?f= filters.
const String searchHelpBody = """
<p><b>Карельский язык</b></p>
<p>Поиск идёт по <b>заглавному слову</b> статьи. Совпадение полное: часть слова сама по себе не ищется — для этого есть шаблоны ниже.</p>
<p>Диакритика (надстрочные и подстрочные знаки) не учитывается: запрос <b>hilla</b> находит и <b>hil’l’a</b>, и <b>hilla</b>. Символы <b>||</b> и <b>|</b> в запросе игнорируются.</p>
<p>Полугласный <b>w</b> в индексе приравнен к <b>u</b>, <b>y</b> или <b>v</b>. Согласные «с птичками» (<b>č</b>, <b>š</b>, <b>ž</b>) можно вводить без надстрочных знаков. <b>ü</b> и <b>y</b> — один звук в разных алфавитах. Весьегонскую графему <b>i̮</b> можно заменить на <b>i</b>.</p>
<p>Гласные <b>ü</b> (=<b>y</b>), <b>ä</b>, <b>ö</b> <b>не</b> сводятся к «голым» <b>u</b>, <b>a</b>, <b>o</b>: гармония гласных смыслоразличительна.</p>
<p>Шаблоны: одна любая буква — «<b>.</b>»; любое количество символов — «<b>?</b>» (например, <b>boi?</b> → <b>boila</b>).</p>
<p>Если точного совпадения нет, приложение предложит близкие по написанию слова (небольшая опечатка).</p>
<p><b>Русский язык</b></p>
<p>Поиск идёт по <b>переводам</b>: начало слова (<b>кош</b> → <b>кошка</b>, <b>кошелёк</b>…). Буква <b>ё</b> приравнивается к <b>е</b>. Леммы, уточнения «точный смысл» и подсказки при опечатках есть только на <a href="$siteBaseUrl/">сайте</a>.</p>
""";

const String rightsHolderLine = "КарНЦ РАН";

const String updateDbMenuLabel = "Проверить и загрузить обновление БД";
const String updateDbPaneTitle = "Обновление словаря";

/// Non-store app update (F2) — shown inside «О приложении».
/// Keep labels short: FilledButton clips long Russian lines on narrow drawers.
const String checkAppUpdateLabel = "Проверить обновление";
const String downloadAppUpdateLabel = "Скачать";
