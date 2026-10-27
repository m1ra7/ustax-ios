from pathlib import Path
import hashlib,json,plistlib
root=Path(__file__).resolve().parent.parent
ID=lambda name:hashlib.sha256(name.encode()).hexdigest()[:24].upper()
q=lambda s:json.dumps(str(s))
objects={}
def obj(name,text):objects[ID(name)]=text;return ID(name)
def refs(items):return '('+', '.join(i for i in items)+', )' if items else '()'
appfiles=sorted((root/'UstaX').rglob('*.swift'));testfiles=sorted((root/'UstaXTests').glob('*.swift'));resources=[root/'UstaX/Resources/Translations.json',root/'UstaX/Resources/LaunchScreen.storyboard',root/'UstaX/Assets.xcassets']+sorted((root/'UstaX/Resources/Icons').glob('*.png'))
file_ids=[];app_build=[];test_build=[];res_build=[]
for path in appfiles+testfiles+resources:
 rel=str(path.relative_to(root));filetype='sourcecode.swift' if path.suffix=='.swift' else 'folder.assetcatalog' if path.suffix=='.xcassets' else 'image.png' if path.suffix=='.png' else 'file.storyboard' if path.suffix=='.storyboard' else 'text.json'
 fid=obj('file:'+rel,'{isa = PBXFileReference; lastKnownFileType = '+filetype+'; path = '+q(rel)+'; sourceTree = SOURCE_ROOT; }');file_ids.append(fid)
 bid=obj('build:'+rel,'{isa = PBXBuildFile; fileRef = '+fid+'; }')
 (app_build if path in appfiles else test_build if path in testfiles else res_build).append(bid)
localized=[]
for lang in ['tr','en','de']:
 localized.append(obj('locale:'+lang,'{isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = '+lang+'; path = '+q('UstaX/Resources/'+lang+'.lproj/InfoPlist.strings')+'; sourceTree = SOURCE_ROOT; }'))
variant=obj('locale:group','{isa = PBXVariantGroup; children = '+refs(localized)+'; name = InfoPlist.strings; sourceTree = "<group>"; }');file_ids.append(variant)
res_build.append(obj('locale:build','{isa = PBXBuildFile; fileRef = '+variant+'; }'))
app_product=obj('product:app','{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = UstaX.app; sourceTree = BUILT_PRODUCTS_DIR; }')
test_product=obj('product:test','{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = UstaXTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }')
products=obj('products','{isa = PBXGroup; children = '+refs([app_product,test_product])+'; name = Products; sourceTree = "<group>"; }')
main=obj('main','{isa = PBXGroup; children = '+refs(file_ids+[products])+'; sourceTree = "<group>"; }')
def phase(name,kind,files):return obj(name,'{isa = '+kind+'; buildActionMask = 2147483647; files = '+refs(files)+'; runOnlyForDeploymentPostprocessing = 0; }')
aps=phase('app:sources','PBXSourcesBuildPhase',app_build);apr=phase('app:resources','PBXResourcesBuildPhase',res_build);apf=phase('app:frameworks','PBXFrameworksBuildPhase',[])
tes=phase('test:sources','PBXSourcesBuildPhase',test_build);ter=phase('test:resources','PBXResourcesBuildPhase',[]);tef=phase('test:frameworks','PBXFrameworksBuildPhase',[])
def config(name,settings):return obj(name,'{isa = XCBuildConfiguration; buildSettings = {'+' '.join(k+' = '+q(v)+';' for k,v in settings.items())+'}; name = '+q(name.split(':')[-1])+'; }')
def configs(prefix,common):
 ids=[]
 for mode in ['Debug','Release']:
  s=dict(common);s.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else 'dwarf-with-dsym'})
  if mode=='Debug':s.update({'ENABLE_TESTABILITY':'YES','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG','GCC_PREPROCESSOR_DEFINITIONS':'DEBUG=1 $(inherited)'})
  ids.append(config(prefix+':'+mode,s))
 return obj(prefix+':configlist','{isa = XCConfigurationList; buildConfigurations = '+refs(ids)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }')
project_configs=configs('project',{'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'16.0','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','SWIFT_VERSION':'5.0','GCC_C_LANGUAGE_STANDARD':'gnu11','CLANG_CXX_LANGUAGE_STANDARD':'gnu++17','ENABLE_USER_SCRIPT_SANDBOXING':'NO'})
app_configs=configs('app',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.miracsoft.ustax','INFOPLIST_FILE':'UstaX/Info.plist','GENERATE_INFOPLIST_FILE':'NO','CODE_SIGN_STYLE':'Automatic','DEVELOPMENT_TEAM':'','TARGETED_DEVICE_FAMILY':'1,2','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SWIFT_EMIT_LOC_STRINGS':'YES','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME':'AccentColor','MARKETING_VERSION':'1.0.0','CURRENT_PROJECT_VERSION':'1','ENABLE_PREVIEWS':'YES'})
test_configs=configs('test',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.miracsoft.ustax.tests','GENERATE_INFOPLIST_FILE':'YES','CODE_SIGN_STYLE':'Automatic','DEVELOPMENT_TEAM':'','TARGETED_DEVICE_FAMILY':'1,2','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/UstaX.app/UstaX','BUNDLE_LOADER':'$(TEST_HOST)','TEST_TARGET_NAME':'UstaX'})
app_id=ID('app:target');test_id=ID('test:target');project_id=ID('project')
proxy=obj('test:proxy','{isa = PBXContainerItemProxy; containerPortal = '+project_id+'; proxyType = 1; remoteGlobalIDString = '+app_id+'; remoteInfo = UstaX; }')
dependency=obj('test:dependency','{isa = PBXTargetDependency; target = '+app_id+'; targetProxy = '+proxy+'; }')
obj('app:target','{isa = PBXNativeTarget; buildConfigurationList = '+app_configs+'; buildPhases = '+refs([aps,apf,apr])+'; buildRules = (); dependencies = (); name = UstaX; productName = UstaX; productReference = '+app_product+'; productType = "com.apple.product-type.application"; }')
obj('test:target','{isa = PBXNativeTarget; buildConfigurationList = '+test_configs+'; buildPhases = '+refs([tes,tef,ter])+'; buildRules = (); dependencies = '+refs([dependency])+'; name = UstaXTests; productName = UstaXTests; productReference = '+test_product+'; productType = "com.apple.product-type.bundle.unit-test"; }')
obj('project','{isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1420; LastSwiftUpdateCheck = 1420; TargetAttributes = {'+app_id+' = {CreatedOnToolsVersion = 14.2; }; '+test_id+' = {CreatedOnToolsVersion = 14.2; TestTargetID = '+app_id+'; }; }; }; buildConfigurationList = '+project_configs+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = tr; hasScannedForEncodings = 0; knownRegions = (tr, en, de, Base); mainGroup = '+main+'; productRefGroup = '+products+'; projectDirPath = ""; projectRoot = ""; targets = '+refs([app_id,test_id])+'; }')
proj=root/'UstaX.xcodeproj';(proj/'xcshareddata/xcschemes').mkdir(parents=True,exist_ok=True)
(proj/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(key+' = '+value+';' for key,value in objects.items())+'\n}; rootObject = '+project_id+'; }\n')
(proj/'project.xcworkspace').mkdir(exist_ok=True);(proj/'project.xcworkspace/contents.xcworkspacedata').write_text('<?xml version="1.0" encoding="UTF-8"?><Workspace version="1.0"><FileRef location="self:"></FileRef></Workspace>')
ref=lambda ident,name,product:f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:UstaX.xcodeproj"/>'
(proj/'xcshareddata/xcschemes/UstaX.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1420" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref(app_id,'UstaX','UstaX.app')}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref(test_id,'UstaXTests','UstaXTests.xctest')}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(app_id,'UstaX','UstaX.app')}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(app_id,'UstaX','UstaX.app')}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
info={'CFBundleDevelopmentRegion':'tr','CFBundleDisplayName':'UstaX','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)','CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)','LSRequiresIPhoneOS':True,'UIStatusBarHidden':False,'UIViewControllerBasedStatusBarAppearance':True,'UILaunchStoryboardName':'LaunchScreen','UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'UISupportedInterfaceOrientations~ipad':['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'NSCameraUsageDescription':'Cihaz kabulü ve tamir fotoğraflarını kaydetmek için kamera erişimi gerekir.','NSLocalNetworkUsageDescription':'Yerel geliştirme sunucusuna bağlanmak için yerel ağ erişimi gerekir.','NSAppTransportSecurity':{'NSAllowsLocalNetworking':True},'CFBundleLocalizations':['tr','en','de'],'ServicePhone':''}
info['CFBundleIcons']={'CFBundleAlternateIcons':{name:{'CFBundleIconFiles':['Icon'+variant],'UIPrerenderedIcon':False} for name,variant in [('UstaXTeal','Teal'),('UstaXIvory','Ivory')]}}
info['CFBundleIcons~ipad']={'CFBundleAlternateIcons':{name:{'CFBundleIconFiles':['Icon'+variant,'Icon'+variant+'83.5'],'UIPrerenderedIcon':False} for name,variant in [('UstaXTeal','Teal'),('UstaXIvory','Ivory')]}}
with (root/'UstaX/Info.plist').open('wb') as f:plistlib.dump(info,f,sort_keys=False)
assets=root/'UstaX/Assets.xcassets';(assets/'AccentColor.colorset').mkdir(parents=True,exist_ok=True)
(assets/'Contents.json').write_text(json.dumps({'info':{'version':1,'author':'UstaX'}}))
if not (assets/'AccentColor.colorset/Contents.json').exists(): (assets/'AccentColor.colorset/Contents.json').write_text(json.dumps({'colors':[{'idiom':'universal','color':{'color-space':'srgb','components':{'red':'0.133','green':'0.337','blue':'0.663','alpha':'1.000'}}}], 'info':{'version':1,'author':'UstaX'}}))
print('Xcode 14 project generated:',len(appfiles),'app Swift files,',len(objects),'objects')
