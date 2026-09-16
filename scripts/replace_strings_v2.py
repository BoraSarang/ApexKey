#!/usr/bin/env python3
"""
Text("...") → Text(localized: "key") 치환기 v2
- ASCII-only 키 사용
- 이미 localized 사용 중인 것 건너뜀
- 인터폴레이션 포함된 것 건너뜀
"""
import re
import hashlib
from pathlib import Path

SRC_ROOT = Path("/Users/lee/Documents/Apps/ApexKey/Sources/ApexKey")

def load_strings_dict(lproj_path: Path) -> dict:
    content = lproj_path.read_text(encoding="utf-16")
    mapping = {}
    for m in re.finditer(r'"([^"]+)"\s*=\s*"([^"]+)";', content):
        mapping[m.group(2)] = m.group(1)
    return mapping

ko_map = load_strings_dict(SRC_ROOT / "ko.lproj" / "Localizable.strings")
en_map = load_strings_dict(SRC_ROOT / "en.lproj" / "Localizable.strings")

# Use ko_map as value->key (ko has the actual Korean values we're replacing)
value_to_key = ko_map

# Also add action keys from ActionType
action_values = {
    '앱 실행/토글': 'action.launchApp',
    '메뉴 명령': 'action.menuCommand',
    '파일/폴더': 'action.file',
    'URL': 'action.url',
    '스크립트': 'action.script',
    '시스템': 'action.system',
    '붙여넣기': 'action.paste',
    '대기': 'action.wait',
    '좌표 클릭': 'action.coordinateClick',
    '입력 대기': 'action.pauseUntilInput',
    '매크로 녹화': 'action.macro',
    '대화상자': 'action.dialog',
    '텍스트': 'action.text',
    '클립보드에서 텍스트 지정': 'action.clipText',
    '앱 전면으로 이동': 'action.moveToFront',
    '화면 깨우기': 'action.wakeDisplay',
    '최근 항목 지우기': 'action.clearRecents',
    '잠자기 방지': 'action.preventSleep',
    '배경화면': 'action.wallpaper',
    '다크모드': 'action.darkMode',
    '집중모드': 'action.focusMode',
    '스크린샷': 'action.screenshot',
    'PDF': 'action.pdf',
    'Wi-Fi': 'action.network',
    '블루투스': 'action.bluetooth',
    '타이머': 'action.timer',
    '스톱워치': 'action.stopwatch',
    '위치': 'action.location',
    'AirDrop': 'action.airDrop',
    '빠른 메모': 'action.newQuickNote',
    '새 메모': 'action.newNote',
    '테이블 읽기': 'action.readTable',
    '이메일 데이터': 'action.emailData',
    '날짜': 'action.date',
    'AppleScript': 'action.appleScript',
    'JavaScript for Automation': 'action.javaScriptForAutomation',
    '빠르게 보기': 'action.quickLook',
    '포토북': 'action.photos',
    '음악 & 비디오': 'action.musicAndVideo',
    '음악 재생': 'action.playMusic',
    '팟캐스트 재생': 'action.playPodcast',
    'TuneIn 라디오': 'action.tuneStation',
    '라디오': 'action.radio',
    '포토북 보기': 'action.viewPhotos',
    '포토북 앨범': 'action.album',
    '무작위 사진': 'action.randomPhoto',
    '슬라이드쇼': 'action.slideshow',
    '최근 사진': 'action.getLastPhoto',
    '카메라': 'action.camera',
    '이미지 회전': 'action.rotateImage',
    '이미지 자르기': 'action.cropImage',
    '비디오 자르기': 'action.trimVideo',
    '스크린샷 캡처': 'action.takeScreenshot',
    '출력 저장': 'action.saveOutput',
    '미디어 볼륨': 'action.setVolumeMedia',
    '미디어 파일 이동': 'action.moveMedia',
    '즐겨찾기': 'action.bookmark',
    '팟캐스트': 'action.podcasts',
    '뉴스': 'action.news',
    '주식': 'action.stocks',
    '비디오 다운로더': 'action.videoDownloader',
    '문서 편집': 'action.editDocument',
    '번역': 'action.translate',
    '텍스트 편집기 단축어': 'action.textEditShortcut',
    '메모 동작': 'action.noteActions',
    '메모 만들기': 'action.createNote',
    '단락 스타일': 'action.setParagraphStyle',
    '새 문서': 'action.newDocument',
    '문서 보기': 'action.viewDocument',
    '메일': 'action.mail',
    '메일 본문 설정': 'action.setMailBody',
    '메일 수신자 설정': 'action.setMailRecipients',
    'OneDrive': 'action.oneDrive',
    'Box': 'action.box',
    '파일 가져오기': 'action.getFiles',
    '파일 이동': 'action.moveFiles',
    '파일 이름 바꾸기': 'action.renameFiles',
    '압축 풀기': 'action.extractArchive',
    '외부 저장소': 'action.externalStorage',
    '파일 동작': 'action.fileActions',
    '확인 가져오기': 'action.getConfirmation',
    '첨부 파일 가져오기': 'action.getAttachment',
    '딕셔너리 가져오기': 'action.getDictionary',
    '날짜 형식': 'action.dateFormatter',
    '리스트 동작': 'action.listActions',
    '날짜 조정': 'action.adjustDate',
    '숫자 형식': 'action.formatNumber',
    '수학': 'action.math',
    '해시': 'action.hash',
    'UUID': 'action.uuid',
    '출력 차이': 'action.outputDifference',
    '숫자 입력': 'action.typeNumber',
    '텍스트 입력': 'action.typeText',
    '클립보드 가져오기': 'action.getClipboard',
    '클립보드 설정': 'action.setClipboard',
    '정규 표현식': 'action.regex',
    '날짜/시간 입력': 'action.typeDateTime',
    '정렬': 'action.sort',
    '대소문자 변경': 'action.changeCase',
    '텍스트 교체': 'action.replaceText',
    '텍스트 결합': 'action.combineText',
    '텍스트 일치': 'action.matchText',
    '텍스트 분리': 'action.splitText',
    '공백 정리': 'action.trimWhitespace',
    '텍스트 감싸기': 'action.surroundText',
    '개수 세기': 'action.count',
    '단어 세기': 'action.wordCount',
    '계산': 'action.calculate',
    'Base64': 'action.base64Encode',
    'HTML→Markdown': 'action.htmlToMarkdown',
    '측정': 'action.measurement',
    'QR 코드 스캔': 'action.scanQRCode',
    '텍스트 인식': 'action.recognizeText',
    '동물 인식': 'action.recognizeAnimal',
    '언어 감지': 'action.detectLanguage',
    '지도': 'action.map',
    '대중교통': 'action.transportation',
    '메시지': 'action.message',
    '이메일': 'action.email',
    '캘린더': 'action.calendar',
    '할일': 'action.reminders',
    '웹 콘텐츠': 'action.webContent',
    '프레젠테이션': 'action.presentation',
    '웹 연동': 'action.webIntegration',
    '문서 & 파일': 'action.documentsAndFiles',
    '주변기기 & 시트': 'action.devicesAndSheet',
    '단축어 아이콘': 'action.createShortcutIcon',
    '단축어 실행': 'action.runShortcut',
    '반복': 'action.repeatLoop',
    '각 항목마다 반복': 'action.repeatEach',
    'If/Otherwise': 'action.ifElse',
    '반복 종료': 'action.endRepeat',
    '단축어 중지': 'action.stopShortcut',
    '메뉴에서 선택': 'action.chooseFromMenu',
    '코멘트': 'action.comment',
    '변수 설정': 'action.setVariable',
    '변수 상세': 'action.variableDetail',
    '클립보드 액션': 'action.clipboardAction',
    '쉘에서 스크립트 실행': 'action.runScriptInShell',
    '숫자': 'action.number',
    '출력을 변수로': 'action.outputToVariable',
    '모델 사용': 'action.useModel',
    '라이팅 툴': 'action.writingTool',
    '이미지 플레이그라운드': 'action.imagePlayground',
    '앱 (Intent)': 'action.appIntent',
    '앱 동작': 'action.appAction',
    '앱 검색': 'action.findApp',
    '개인 자동화': 'action.automation',
    '자동화 검색': 'action.findAutomation',
    '자동화에서 실행': 'action.automationRun',
    '트리거': 'action.trigger',
}

# Merge
for v, k in action_values.items():
    if v not in ko_map:
        ko_map[v] = k

print(f"총 매핑: {len(ko_map)}개")

# Replace in files
text_pattern = re.compile(r'Text\(\s*"([^"]+)"\s*\)')
total_replaced = 0

for f in SRC_ROOT.rglob("*.swift"):
    if any(ex in f.parts for ex in {".build", "build", "DerivedData"}):
        continue
    content = f.read_text(encoding="utf-8")
    original = content
    
    def replacer(match):
        full = match.group(0)
        value = match.group(1)
        if ".localized" in full:
            return full
        if "{" in value or "%" in value or "\\(" in value:
            return full
        key = ko_map.get(value)
        if key:
            return f'Text(localized: "{key}")'
        return full
    
    new_content = text_pattern.sub(replacer, content)
    if new_content != original:
        f.write_text(new_content, encoding="utf-8")
        total_replaced += 1
        print(f"  {f.name}: 치환됨")

print(f"\n총 {total_replaced}개 파일 치환 완료")