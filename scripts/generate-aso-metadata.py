#!/usr/bin/env python3
"""Generate and validate DUPR IQ App Store metadata for every target locale."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "fastlane/metadata"
LOCALES_FILE = ROOT / "scripts/asc-supported-locales.json"
SUPPORT_URL = "https://jackwallner.github.io/pickleball/support"
MARKETING_URL = "https://jackwallner.github.io/pickleball/"
PRIVACY_URL = "https://jackwallner.github.io/pickleball/privacy-policy"
EULA_URL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

DESCRIPTION = f"""Stand on the court, read the rally, and choose the shot that wins the point.

DUPR IQ puts you in the point. Every ball is a real doubles position seen from where you are standing: four players, a ball hanging at an actual height beside the net tape, and the score. Nothing is written down for you. You read ball height, court position, and whether feet have reached the kitchen line.

You answer by aiming. Four rings sit on the paint where each shot would land, so you pick the place, not a sentence from a list. Then see why the answer is the answer, named as a coaching principle, with an overhead diagram if you want the whiteboard view.

Points, not flashcards. Get the read right and the rally continues to your next shot. Get it wrong and you lose the point, the way you would in a game.

Practice starts untimed while you learn the court. When ready, turn on the optional decision timer at learning, game, or fast pace.

Practice by phase:
- Return of serve
- Third shot drop or drive
- Transition zone
- Dink rally
- Attacking a high ball
- Playing defense

The free app gives you 15 graded balls a day across all six phases, with your accuracy in each of them. DUPR IQ Pro removes the daily limit and adds session history plus ranked missed principles, so you know what to drill next.

Positions are generated, not pulled from a fixed question bank, so practice never runs out.

Subscription details:
DUPR IQ Pro offers monthly and yearly auto-renewing subscriptions, plus a one-time lifetime purchase. Eligible customers may receive a one-week free trial on a subscription; Apple determines eligibility. Payment is charged to your Apple Account when you confirm the purchase, or when a trial ends. A subscription renews automatically unless canceled at least 24 hours before the current period ends. Your account is charged for renewal within 24 hours before the period ends. Manage or cancel subscriptions in Apple Account Settings > Subscriptions. Prices are shown in the app before purchase and vary by region. Any unused free-trial period ends when you purchase a subscription.

Privacy Policy: {PRIVACY_URL}
Apple Standard EULA: {EULA_URL}"""


def item(name: str, subtitle: str, keywords: str, promo: str, release_notes: str) -> dict[str, str]:
    return {
        "name": name,
        "subtitle": subtitle,
        "keywords": keywords,
        "description": DESCRIPTION,
        "promotional_text": promo,
        "release_notes": release_notes,
        "support_url": SUPPORT_URL,
        "marketing_url": MARKETING_URL,
        "privacy_url": PRIVACY_URL,
    }


ENGLISH = item(
    "DUPR IQ - Pickleball Drills",
    "Pickleball Drills & Tactics",
    "dink,kitchen,thirdshot,drop,drive,serve,return,volley,coach,practice,tactics,strategy,shotselection",
    "Read the ball. Choose the shot. Train your pickleball game.",
    "First release: generated pickleball shot-selection drills.",
)

SPANISH = item(
    "DUPR IQ - Entrena Pickleball",
    "Drills y táctica de golpes",
    "entreno,táctica,golpe,saque,resto,tercergolpe,dink,drop,drive,volea,cocina,coach,seleccióngolpe",
    "Lee la pelota, elige el golpe y mejora tu juego.",
    "Primera versión: drills de selección de golpes.",
)

FRENCH = item(
    "DUPR IQ - Drills Pickleball",
    "Choix du coup et tactique",
    "entraînement,tactique,coup,service,retour,troisièmecoup,dink,drop,drive,volée,cuisine,coach,jeu",
    "Lisez la balle, choisissez le coup, jouez plus juste.",
    "Première version : drills de choix de coups.",
)

PORTUGUESE = item(
    "DUPR IQ - Treino Pickleball",
    "Escolha de golpes e tática",
    "treino,tática,golpe,saque,recepção,terceirogolpe,dink,drop,drive,voleio,cozinha,escolhadegolpe,jogo",
    "Leia a bola, escolha o golpe e evolua no jogo.",
    "Primeira versão: treino de escolha de golpes.",
)

GERMAN = item(
    "DUPR IQ - Pickleball-Training",
    "Schlagwahl und Spieltaktik",
    "dink,küche,dritterball,drop,drive,aufschlag,return,volley,training,coach,taktik,schlagwahl,spiel",
    "Ball lesen, Schlag wählen, besser Pickleball spielen.",
    "Erste Version: Übungen zur Schlagwahl.",
)

ITALIAN = item(
    "DUPR IQ - Drill Pickleball",
    "Scelta del colpo e tattica",
    "allenamento,tattica,colpo,servizio,risposta,terzocolpo,dink,drop,drive,volée,cucina,coach,partita",
    "Leggi la palla, scegli il colpo, gioca meglio.",
    "Prima versione: drill sulla scelta del colpo.",
)

JAPANESE = item(
    "DUPR IQ - ピックルボール練習ドリル",
    "ピックルボールのショット選択と戦術練習",
    "練習,戦術,ショット,サーブ,リターン,サードショット,ディンク,ドロップ,ドライブ,ボレー,キッチン,コーチ,ショット選択,試合,pickleball,training,coach,serve",
    "ボールを読み、ショットを選び、実戦力を磨く。",
    "初回リリース: ショット選択ドリル。",
)

CHINESE_SIMPLIFIED = item(
    "DUPR IQ - 匹克球训练与战术",
    "匹克球击球选择与实战战术",
    "训练,战术,击球,发球,接发球,第三拍,吊球,抽球,截击,厨房线,教练,击球选择,实战练习,回球策略,pickleball,drill,training,coach,serve,return",
    "看清来球，选对击球，提升匹克球实战判断。",
    "首发版本：击球选择训练。",
)

CHINESE_TRADITIONAL = item(
    "DUPR IQ - 匹克球訓練與戰術",
    "匹克球擊球選擇與實戰戰術",
    "訓練,戰術,擊球,發球,接發球,第三拍,吊球,抽球,截擊,廚房線,教練,擊球選擇,實戰練習,回球策略,pickleball,drill,training,coach,serve,return",
    "看清來球，選對擊球，提升匹克球實戰判斷。",
    "首發版本：擊球選擇訓練。",
)


METADATA: dict[str, dict[str, str]] = {}


def assign(locales: list[str], value: dict[str, str]) -> None:
    for locale in locales:
        METADATA[locale] = dict(value)


assign(["en-AU", "en-CA", "en-GB", "en-US"], ENGLISH)
assign(["es-ES", "es-MX"], SPANISH)
assign(["fr-CA", "fr-FR"], FRENCH)
assign(["pt-BR", "pt-PT"], PORTUGUESE)
assign(["de-DE"], GERMAN)
assign(["it"], ITALIAN)
assign(["ja"], JAPANESE)
assign(["zh-Hans"], CHINESE_SIMPLIFIED)
assign(["zh-Hant"], CHINESE_TRADITIONAL)

assign(
    ["ar-SA"],
    item(
        "DUPR IQ - تمارين بيكلبول",
        "تدريبات بيكلبول وتكتيك",
        "بيكلبول,تمارين,تدريب,تكتيك,ضربة,إرسال,إرجاع,ضربةثالثة,دنك,فولي,مطبخ,استراتيجية,اختيارالضربة,تطوير",
        "اقرأ الكرة، اختر الضربة، وطوّر لعبك.",
        "الإصدار الأول: تمارين اختيار الضربة.",
    ),
)
assign(
    ["bn-BD"],
    item(
        "DUPR IQ - পিকলবল ড্রিলস",
        "পিকলবল ড্রিল ও কৌশল অনুশীলন",
        "পিকলবল,ড্রিল,অনুশীলন,প্রশিক্ষণ,শট,কৌশল,সার্ভ,রিটার্ন,থার্ডশট,ডিঙ্ক,ভলি,কিচেন,শটনির্বাচন,কোর্ট,খেলা",
        "বল পড়ুন, শট বাছুন, খেলায় উন্নতি করুন।",
        "প্রথম সংস্করণ: শট বাছাইয়ের ড্রিল।",
    ),
)
assign(
    ["ca"],
    item(
        "DUPR IQ - Pràctica Pickleball",
        "Drills i tàctica de cops",
        "entrenament,tàctica,cop,servei,resta,tercercop,dink,drop,drive,volea,cuina,selecciódecop,pickleball",
        "Llegeix la pilota, tria el cop i millora el teu joc.",
        "Primera versió: drills de selecció de cops.",
    ),
)
assign(
    ["cs"],
    item(
        "DUPR IQ - Trénink Pickleball",
        "Volba úderu, taktika hry",
        "trénink,taktika,úder,podání,return,třetíúder,dink,drop,drive,volej,kuchyně,trenér,výběrúderu,hra",
        "Čti míč, zvol úder a hraj pickleball chytřeji.",
        "První verze: trénink volby úderu.",
    ),
)
assign(
    ["da"],
    item(
        "DUPR IQ - Pickleballtræning",
        "Vælg slaget, spil smartere",
        "træning,taktik,slag,serv,return,tredjeslag,dink,drop,drive,flugtning,køkken,coach,slagvalg,øvelse",
        "Læs bolden, vælg slaget, og spil bedre.",
        "Første version: træning i slagvalg.",
    ),
)
assign(
    ["el"],
    item(
        "DUPR IQ - Pickleball Drills",
        "Επιλογή χτυπήματος τώρα",
        "προπόνηση,τακτική,χτύπημα,σερβίς,επιστροφή,τρίτοχτύπημα,dink,drop,drive,volley,κουζίνα,προπονητής",
        "Διάβασε την μπάλα, διάλεξε χτύπημα, παίξε καλύτερα.",
        "Πρώτη έκδοση: drills επιλογής χτυπήματος.",
    ),
)
assign(
    ["fi"],
    item(
        "DUPR IQ - Pickleballtreeni",
        "Valitse lyönti, pelaa hyvin",
        "harjoittelu,taktiikka,lyönti,syöttö,palautus,kolmaslyönti,dink,drop,drive,keittiö,lyöntivalinta",
        "Lue pallo, valitse lyönti ja pelaa fiksummin.",
        "Ensimmäinen julkaisu: lyöntivalinnan harjoittelu.",
    ),
)
assign(
    ["gu-IN"],
    item(
        "DUPR IQ - પિકલબોલ ડ્રિલ્સ",
        "શોટ પસંદગી અને વ્યૂહરચના",
        "પિકલબોલ,ડ્રિલ,અભ્યાસ,તાલીમ,શોટ,વ્યૂહરચના,સર્વ,રિટર્ન,ત્રીજો શોટ,ડિંક,વોલી,કિચન,કોચ,શોટ પસંદગી,રમત",
        "બૉલ વાંચો, શોટ પસંદ કરો અને રમત સુધારો.",
        "પ્રથમ આવૃત્તિ: શોટ પસંદગીની ડ્રિલ્સ.",
    ),
)
assign(
    ["he"],
    item(
        "DUPR IQ - אימון פיקלבול חכם",
        "בחירת חבטה וטקטיקה למשחק",
        "אימון,טקטיקה,חבטה,הגשה,החזרה,חבטהשלישית,dink,drop,drive,וולי,מטבח,מאמן,בחירתחבטה,אסטרטגיה,משחק",
        "קראו את הכדור, בחרו חבטה ושחקו חכם יותר.",
        "גרסה ראשונה: אימוני בחירת חבטה.",
    ),
)
assign(
    ["hi"],
    item(
        "DUPR IQ - पिकलबॉल ड्रिल्स",
        "शॉट चयन और खेल रणनीति",
        "अभ्यास,रणनीति,शॉट,सर्व,रिटर्न,तीराशॉट,डिंक,ड्रॉप,ड्राइव,वॉली,किचन,कोच,शॉटचयन,खेल,पिकलबॉल,प्लेसमेंट",
        "गेंद पढ़ें, शॉट चुनें और अपना खेल बेहतर करें।",
        "पहला संस्करण: शॉट चयन अभ्यास।",
    ),
)
assign(
    ["hr"],
    item(
        "DUPR IQ - Trening Pickleball",
        "Izbor udarca i taktika igre",
        "trening,taktika,udarac,servis,povrat,trećiudarac,dink,drop,drive,volej,kuhinja,trener,izborudarca",
        "Čitaj loptu, odaberi udarac i igraj bolje.",
        "Prva verzija: trening izbora udarca.",
    ),
)
assign(
    ["hu"],
    item(
        "DUPR IQ - Pickleball edzés",
        "Ütésválasztás és taktika",
        "edzés,taktika,ütés,szerva,visszaütés,harmadikütés,dink,drop,drive,röpte,konyha,edző,ütésválasztás",
        "Olvasd a labdát, válaszd az ütést, játssz jobban.",
        "Első kiadás: ütésválasztási edzés.",
    ),
)
assign(
    ["id"],
    item(
        "DUPR IQ - Latihan Pickleball",
        "Pilih pukulan, main cerdas",
        "latihan,taktik,pukulan,servis,return,pukulanketiga,dink,drop,drive,voli,dapur,pelatih,pilihanpukulan",
        "Baca bola, pilih pukulan, dan tingkatkan permainan.",
        "Rilis pertama: latihan memilih pukulan.",
    ),
)
assign(
    ["kn-IN"],
    item(
        "DUPR IQ - ಪಿಕಲ್‌ಬಾಲ್ ಅಭ್ಯಾಸ",
        "ಶಾಟ್ ಆಯ್ಕೆ ಮತ್ತು ಆಟದ ತಂತ್ರ",
        "ಪಿಕಲ್‌ಬಾಲ್,ಅಭ್ಯಾಸ,ತರಬೇತಿ,ತಂತ್ರ,ಶಾಟ್,ಸರ್ವ್,ರಿಟರ್ನ್,ಮೂರನೇಶಾಟ್,ಡಿಂಕ್,ಡ್ರಾಪ್,ಡ್ರೈವ್,ವಾಲಿ,ಕಿಚನ್,ಶಾಟ್ಆಯ್ಕೆ",
        "ಬಾಲ್ ಓದಿ, ಶಾಟ್ ಆಯ್ಕೆ ಮಾಡಿ, ಆಟವನ್ನು ಉತ್ತಮಗೊಳಿಸಿ.",
        "ಮೊದಲ ಆವೃತ್ತಿ: ಶಾಟ್ ಆಯ್ಕೆ ಅಭ್ಯಾಸ.",
    ),
)
assign(
    ["ko"],
    item(
        "DUPR IQ - 피클볼 훈련 드릴",
        "샷 선택과 경기 전략 연습",
        "피클볼,훈련,연습,전략,샷,서브,리턴,세번째샷,딩크,드롭,드라이브,발리,키친,코치,샷선택,경기,pickleball,training,coach,shotselection,dink",
        "공을 읽고 샷을 선택해 경기력을 높이세요.",
        "첫 출시: 샷 선택 훈련.",
    ),
)
assign(
    ["ml-IN"],
    item(
        "DUPR IQ - പിക്കിൾബോൾ ഡ്രിൽ",
        "ഷോട്ട് തിരഞ്ഞെടുപ്പും തന്ത്രം",
        "പിക്കിൾബോൾ,പരിശീലനം,തന്ത്രം,ഷോട്ട്,സെർവ്,റിട്ടേൺ,മൂന്നാംഷോട്ട്,ഡിങ്ക്,ഡ്രോപ്പ്,ഡ്രൈവ്,വോളി,കിച്ചൻ",
        "പന്ത് വായിച്ച് ഷോട്ട് തിരഞ്ഞെടുക്കൂ, കളി മെച്ചപ്പെടുത്തൂ.",
        "ആദ്യ പതിപ്പ്: ഷോട്ട് തിരഞ്ഞെടുപ്പ് പരിശീലനം.",
    ),
)
assign(
    ["mr-IN"],
    item(
        "DUPR IQ - पिकलबॉल ड्रिल्स",
        "शॉट निवड आणि खेळाची रणनीती",
        "सराव,रणनीती,शॉट,सर्व्ह,रिटर्न,तिसराशॉट,डिंक,ड्रॉप,ड्राइव्ह,व्हॉली,किचन,कोच,शॉटनिवड,खेळ,पिकलबॉल",
        "चेंडू वाचा, शॉट निवडा आणि खेळ सुधारवा.",
        "पहिली आवृत्ती: शॉट निवडीचा सराव.",
    ),
)
assign(
    ["ms"],
    item(
        "DUPR IQ - Latihan Pickleball",
        "Pilih pukulan, guna taktik",
        "latihan,taktik,pukulan,servis,return,pukulanketiga,dink,drop,drive,voli,dapur,jurulatih,strategi",
        "Baca bola, pilih pukulan dan tingkatkan permainan.",
        "Keluaran pertama: latihan memilih pukulan.",
    ),
)
assign(
    ["nl-NL"],
    item(
        "DUPR IQ - Pickleballtraining",
        "Slagen kiezen, slim spelen",
        "training,tactiek,slag,service,return,derdeslag,dink,drop,drive,volley,keuken,coach,slagkeuze,spel",
        "Lees de bal, kies je slag en speel slimmer.",
        "Eerste versie: training in slagkeuze.",
    ),
)
assign(
    ["no"],
    item(
        "DUPR IQ - Pickleballtrening",
        "Velg slaget, spill smartere",
        "trening,taktikk,slag,serve,retur,tredjeslag,dink,drop,drive,volley,kjøkken,coach,slagvalg,strategi",
        "Les ballen, velg slaget og spill smartere.",
        "Første versjon: trening i slagvalg.",
    ),
)
assign(
    ["or-IN"],
    item(
        "DUPR IQ - ପିକଲବଲ୍ ଡ୍ରିଲ୍ସ",
        "ଶଟ୍ ବାଛନ୍ତୁ, କୌଶଳ ଶିଖନ୍ତୁ",
        "ପିକଲବଲ୍,ଅଭ୍ୟାସ,ପ୍ରଶିକ୍ଷଣ,କୌଶଳ,ଶଟ୍,ସର୍ଭ,ରିଟର୍ନ,ତୃତୀୟଶଟ୍,ଡିଙ୍କ,ଡ୍ରପ୍,ଡ୍ରାଇଭ୍,ଭଲି,କିଚେନ୍,କୋଚ୍,ଶଟ୍ଚୟନ",
        "ବଲ୍ ପଢନ୍ତୁ, ଶଟ୍ ବାଛନ୍ତୁ ଏବଂ ଖେଳ ଉନ୍ନତ କରନ୍ତୁ।",
        "ପ୍ରଥମ ସଂସ୍କରଣ: ଶଟ୍ ଚୟନ ଅଭ୍ୟାସ।",
    ),
)
assign(
    ["pa-IN"],
    item(
        "DUPR IQ - ਪਿਕਲਬਾਲ ਡ੍ਰਿਲਜ਼",
        "ਸ਼ਾਟ ਚੁਣੋ, ਖੇਡ ਦੀ ਰਣਨੀਤੀ",
        "ਪਿਕਲਬਾਲ,ਅਭਿਆਸ,ਟ੍ਰੇਨਿੰਗ,ਰਣਨੀਤੀ,ਸ਼ਾਟ,ਸਰਵ,ਰਿਟਰਨ,ਤੀਜਾਸ਼ਾਟ,ਡਿੰਕ,ਡ੍ਰਾਪ,ਡ੍ਰਾਈਵ,ਵਾਲੀ,ਕਿਚਨ,ਕੋਚ,ਸ਼ਾਟਚੋਣ,ਖੇਡ",
        "ਗੇਂਦ ਪੜ੍ਹੋ, ਸ਼ਾਟ ਚੁਣੋ ਅਤੇ ਆਪਣੀ ਖੇਡ ਸੁਧਾਰੋ।",
        "ਪਹਿਲਾ ਸੰਸਕਰਣ: ਸ਼ਾਟ ਚੋਣ ਦਾ ਅਭਿਆਸ।",
    ),
)
assign(
    ["pl"],
    item(
        "DUPR IQ - Trening Pickleball",
        "Wybór uderzenia i taktyka",
        "trening,taktyka,uderzenie,serwis,return,trzecieuderzenie,dink,drop,drive,kuchnia,wybóruderzenia,gra",
        "Czytaj piłkę, wybierz uderzenie i graj lepiej.",
        "Pierwsza wersja: trening wyboru uderzenia.",
    ),
)
assign(
    ["ro"],
    item(
        "DUPR IQ - Drilluri Pickleball",
        "Alege lovitura, joacă tactic",
        "antrenament,tactică,lovitură,serviciu,retur,dink,drop,drive,voleu,bucătărie,antrenor,strategie,joc",
        "Citește mingea, alege lovitura și joacă mai bine.",
        "Prima versiune: antrenament pentru alegerea loviturii.",
    ),
)
assign(
    ["ru"],
    item(
        "DUPR IQ - Дриллы пиклбола",
        "Выбор удара и тактика игры",
        "тренировка,тактика,удар,подача,приём,третийудар,динк,дроп,драйв,воллей,кухня,выборудара,стратегия",
        "Читайте мяч, выбирайте удар и играйте сильнее.",
        "Первая версия: тренировка выбора удара.",
    ),
)
assign(
    ["sk"],
    item(
        "DUPR IQ - Tréning Pickleball",
        "Voľba úderu a herná taktika",
        "tréning,taktika,úder,podanie,return,tretíúder,dink,drop,drive,volej,kuchyňa,tréner,strategia,hra",
        "Čítaj loptu, zvoľ úder a hraj lepšie.",
        "Prvá verzia: tréning voľby úderu.",
    ),
)
assign(
    ["sl-SI"],
    item(
        "DUPR IQ - Trening Pickleball",
        "Izbira udarca in taktika",
        "trening,taktika,udarec,servis,vračanje,tretjiudarec,dink,drop,drive,volej,kuhinja,izbiraudarca",
        "Preberi žogo, izberi udarec in igraj bolje.",
        "Prva različica: trening izbire udarca.",
    ),
)
assign(
    ["sv"],
    item(
        "DUPR IQ - Pickleballträning",
        "Välj slaget, spela smart",
        "träning,taktik,slag,serve,retur,tredjeslag,dink,drop,drive,volley,kök,coach,slagval,strategi,spel",
        "Läs bollen, välj slaget och spela smartare.",
        "Första versionen: träning i slagval.",
    ),
)
assign(
    ["ta-IN"],
    item(
        "DUPR IQ - பிக்கிள்பால் பயிற்சி",
        "ஷாட் தேர்வு மற்றும் ஆட்ட உத்தி",
        "பயிற்சி,ட்ரில்,உத்தி,ஷாட்,சர்வ்,ரிட்டர்ன்,மூன்றாவதுஷாட்,டிங்க்,டிராப்,டிரைவ்,வாலி,கிச்சன்,ஷாட்தேர்வு",
        "பந்தைப் படித்து, ஷாட்டைத் தேர்ந்து, ஆட்டத்தை மேம்படுத்துங்கள்.",
        "முதல் பதிப்பு: ஷாட் தேர்வு பயிற்சி.",
    ),
)
assign(
    ["te-IN"],
    item(
        "DUPR IQ - పికిల్‌బాల్ డ్రిల్స్",
        "షాట్ ఎంపిక మరియు వ్యూహం",
        "పికిల్‌బాల్,శిక్షణ,డ్రిల్,వ్యూహం,షాట్,సర్వ్,రిటర్న్,మూడవషాట్,డింక్,డ్రాప్,డ్రైవ్,వాలీ,కిచెన్,కోచ్",
        "బంతిని చదివి, షాట్ ఎంచుకుని, ఆటను మెరుగుపరచండి.",
        "మొదటి విడుదల: షాట్ ఎంపిక శిక్షణ.",
    ),
)
assign(
    ["th"],
    item(
        "DUPR IQ - ฝึกพิกเคิลบอล",
        "เลือกช็อตและวางแผนเกมให้แม่น",
        "ฝึกซ้อม,เทคนิค,กลยุทธ์,ช็อต,เสิร์ฟ,รีเทิร์น,ช็อตที่สาม,dink,drop,drive,วอลเลย์,คิทเช่น,เลือกช็อต",
        "อ่านบอล เลือกช็อต และพัฒนาเกมของคุณ",
        "รุ่นแรก: ฝึกการเลือกช็อต",
    ),
)
assign(
    ["tr"],
    item(
        "DUPR IQ - Pickleball Drill",
        "Vuruş seçimi ve oyun taktiği",
        "antrenman,taktik,vuruş,servis,karşılama,üçüncüşut,dink,drop,drive,vole,mutfak,vuruşseçimi,strateji",
        "Topu oku, vuruşu seç ve daha iyi oyna.",
        "İlk sürüm: vuruş seçimi antrenmanı.",
    ),
)
assign(
    ["uk"],
    item(
        "DUPR IQ - Дрилли піклболу",
        "Вибір удару та тактика гри",
        "тренування,тактика,удар,подача,прийом,третійудар,дінк,дроп,драйв,волей,кухня,вибірудару,стратегія",
        "Читайте м'яч, обирайте удар і грайте краще.",
        "Перша версія: тренування вибору удару.",
    ),
)
assign(
    ["ur-PK"],
    item(
        "DUPR IQ - پکل بال ڈرلز ٹریننگ",
        "شاٹ کا انتخاب اور حکمت عملی",
        "پکل بال,ٹریننگ,مشق,حکمت عملی,شاٹ,سرو,ریٹرن,تیسراشاٹ,ڈنک,ڈراپ,ڈرائیو,والی,کچن,کوچ,شاٹانتخاب,پریکٹس",
        "گیند کو پڑھیں، شاٹ چنیں اور کھیل بہتر بنائیں۔",
        "پہلا ورژن: شاٹ کے انتخاب کی مشق۔",
    ),
)
assign(
    ["vi"],
    item(
        "DUPR IQ - Bài tập Pickleball",
        "Chọn cú đánh, chơi khôn ngoan",
        "luyệntập,chiếnthuật,cúđánh,giao bóng,trả bóng,cú đánh thứ ba,dink,drop,drive,volley,chọncúđánh,serve",
        "Đọc bóng, chọn cú đánh và chơi tốt hơn.",
        "Bản phát hành đầu tiên: luyện chọn cú đánh.",
    ),
)


def validate(locales: list[str]) -> list[str]:
    errors: list[str] = []
    if set(METADATA) != set(locales):
        errors.append(f"locale map mismatch: expected {len(locales)}, got {len(METADATA)}")
    for locale in locales:
        data = METADATA.get(locale)
        if not data:
            errors.append(f"{locale}: missing metadata")
            continue
        for field in ("name", "subtitle"):
            value = data[field]
            if not 1 <= len(value) <= 30:
                errors.append(f"{locale}: {field} is {len(value)} characters, must be 1-30")
        keywords = data["keywords"]
        if not 94 <= len(keywords) <= 100:
            errors.append(f"{locale}: keywords are {len(keywords)} characters, target 94-100")
        if ",," in keywords or keywords.startswith(",") or keywords.endswith(","):
            errors.append(f"{locale}: malformed keyword separators")
        for field in ("description", "promotional_text", "release_notes", "support_url", "marketing_url", "privacy_url"):
            if not data[field].strip():
                errors.append(f"{locale}: empty {field}")
        if any(char in data["description"] for char in ("$", "€", "£")):
            errors.append(f"{locale}: description contains a price symbol")
    return errors


def write_metadata(locales: list[str]) -> None:
    fields = (
        "name",
        "subtitle",
        "keywords",
        "description",
        "promotional_text",
        "release_notes",
        "support_url",
        "marketing_url",
        "privacy_url",
    )
    for locale in locales:
        directory = META / locale
        directory.mkdir(parents=True, exist_ok=True)
        for field in fields:
            (directory / f"{field}.txt").write_text(METADATA[locale][field] + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="validate the map without writing files")
    args = parser.parse_args()
    locales = json.loads(LOCALES_FILE.read_text(encoding="utf-8"))["locales"]
    errors = validate(locales)
    if errors:
        print("\n".join(errors))
        return 1
    if not args.check:
        write_metadata(locales)
    print(f"validated {len(locales)} locales; {'no files written' if args.check else 'metadata generated'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
