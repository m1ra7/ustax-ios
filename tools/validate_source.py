from pathlib import Path
import json,re,plistlib,xml.etree.ElementTree as ET
root=Path(__file__).resolve().parent.parent
source='\n'.join(p.read_text() for p in (root/'UstaX').rglob('*.swift'))
translations=json.loads((root/'UstaX/Resources/Translations.json').read_text())
keys=set(re.findall(r'app\.t\("([^"\\]+)"',source))|set(re.findall(r'AppError\("([^"\\]+)"',source))
missing=keys-set(translations)
assert not missing, 'Missing native translations: '+str(missing)
assert all(v.get('en') and v.get('de') for v in translations.values())
assert not re.search(r'\b(?:ContentUnavailableView|Observable|sensoryFeedback|symbolEffect|containerRelativeFrame)\b',source)
assert not re.search(r'defer\s*\{\s*(?:busy|loading)\s*=', source), 'Swift 5.7 actor cleanup regression'
assert '.onChange(of:' in source
assert not re.search(r'\.onChange\([^\n]*initial:',source)
project=(root/'UstaX.xcodeproj/project.pbxproj').read_text()
assert 'objectVersion = 56;' in project and 'IPHONEOS_DEPLOYMENT_TARGET = "16.0"' in project and 'SWIFT_VERSION = "5.0"' in project
assert 'LastUpgradeCheck = 1420' in project
for path in (root/'UstaX').rglob('*.swift'):assert str(path.relative_to(root)) in project
for path in re.findall(r'path = "([^"]+)"; sourceTree = SOURCE_ROOT;',project):assert (root/path).exists(),path
ET.parse(root/'UstaX.xcodeproj/xcshareddata/xcschemes/UstaX.xcscheme')
info=plistlib.loads((root/'UstaX/Info.plist').read_bytes());assert not info.get('NSAppTransportSecurity',{}).get('NSAllowsArbitraryLoads')
assert info['CFBundleDisplayName']=='UstaX'
assert 'kSecAttrAccessibleWhenUnlockedThisDeviceOnly' in source
assert 'willPerformHTTPRedirection' in source
assert 'DATABASE_URL' not in source and 'RESEND_API_KEY' not in source and 'AWS_SECRET_ACCESS_KEY' not in source
assert 'JSONSerialization.data' in source and 'multipart/form-data' in source
for endpoint in ['auth/login','auth/logout','records','me','users','health']:assert '"'+endpoint+'"' in source
for name in ['quote','complete','deliver','notes','photos','status','decision','code']:assert name in source
assert len(re.findall(r'func test\w+\(', (root/'UstaXTests/UstaXTests.swift').read_text()))==16
assert 'CGImageSourceCreateThumbnailAtIndex' in source
assert 'cache.totalCostLimit = 24 * 1024 * 1024' in source
assert 'active < 3' in source
assert '180_000_000' in source
assert 'decoding.async' in source
assert 'app.records.filter' not in (root/'UstaX/Views/RecordsView.swift').read_text()
assert 'UIImage(data: raw)' not in (root/'UstaX/Views/PhotosView.swift').read_text()
assert 'SessionVault.read(base.absoluteString)' not in (root/'UstaX/Networking/APIClient.swift').read_text()
print('PASS: source references, Xcode 14 settings, resources, translations, API routes and security configuration')
try:
 from tree_sitter import Language,Parser
 import tree_sitter_swift
 parser=Parser(Language(tree_sitter_swift.language()))
 for path in list((root/'UstaX').rglob('*.swift'))+list((root/'UstaXTests').glob('*.swift')):
  tree=parser.parse(path.read_bytes())
  assert not tree.root_node.has_error, str(path)
 print('PASS: Swift source and test files parsed without syntax errors')
except ImportError: print('SKIP: optional Swift syntax parser is not installed')
try:
 from pbxproj import XcodeProject
 assert XcodeProject.load(str(root/'UstaX.xcodeproj/project.pbxproj')) is not None
 print('PASS: OpenStep Xcode project parsed')
except ImportError: print('SKIP: optional Xcode project parser is not installed')
print('Xcode build and XCTest must still be run on macOS.')

assert "Task { @MainActor in self?.clear() }" not in source, "Mutable weak capture in notification task"

launch = ET.parse(root/'UstaX/Resources/LaunchScreen.storyboard').getroot()
assert launch.attrib['launchScreen'] == 'YES'
assert info.get('UILaunchStoryboardName') == 'LaunchScreen'
assert 'UILaunchScreen' not in info
assert 'UstaX/Resources/LaunchScreen.storyboard' in project
assert len(launch.findall('.//constraint')) == 4
for name in ['LaunchBackground', 'LaunchInk']:
 colors = json.loads((root/f'UstaX/Assets.xcassets/{name}.colorset/Contents.json').read_text())['colors']
 assert len(colors) == 2 and colors[1]['appearances'][0]['value'] == 'dark'
print('PASS: launch storyboard, adaptive colors and project configuration')

assets = root/'UstaX/Assets.xcassets'
assert json.loads((assets/'ButtonBlue.colorset/Contents.json').read_text())['colors'][0] == json.loads((assets/'AccentColor.colorset/Contents.json').read_text())['colors'][0]
assert info.get('UIStatusBarHidden') is False
assert 'CircularProgressViewStyle(tint: .white)' in source
assert '.toggleStyle(SwitchToggleStyle(tint: Color("ButtonBlue")))' in source
assert 'ServicePrimaryButtonStyle(loading: busy)' in source
print('PASS: shared control palette, white sign-in indicator and visible status bar')

# Dark text and device icons must remain legible on their actual surfaces.
def luminance(hex_color):
 rgb = [int(hex_color[i:i+2],16)/255 for i in (0,2,4)]
 return sum(k*(v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4) for k,v in zip([.2126,.7152,.0722],rgb))
for background in ['23364A','304E6B']:
 low,high=sorted([luminance('9DC8F5'),luminance(background)])
 assert (high+.05)/(low+.05) >= 4.5
assert 'Color.accentColor.opacity(0.08)' not in source
print('PASS: dark action text and device icon contrast')

for launch_name, app_name in [('LaunchInk','AccentColor')]:
 assert json.loads((assets/f'{launch_name}.colorset/Contents.json').read_text()) == json.loads((assets/f'{app_name}.colorset/Contents.json').read_text())
print('PASS: launch text matches current application theme')

assert json.loads((assets/'LaunchBackground.colorset/Contents.json').read_text()) == json.loads((assets/'AppCanvas.colorset/Contents.json').read_text())
assert launch.find('.//view/color[@key="backgroundColor"]').get('name') == 'AppCanvas'
assert 'ServiceStyle.canvas.ignoresSafeArea()' in source
print('PASS: launch and application use the exact same background asset in both themes')

assert 'await BackgroundWork.catalog(loaded)' in source
assert 'catalog.customerSearchEntries[$0.customerId]' in source
assert 'guard scope == api.mediaScope else' in source
print('PASS: background catalog, indexed customer search and session scope guards')
