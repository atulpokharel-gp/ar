"""Deterministically generate the included Xcode project, without XcodeGen."""
from pathlib import Path
import hashlib
import plistlib
ROOT = Path(__file__).resolve().parents[1]
def ident(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def q(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
objects = []
def obj(name, body):
    objects.append(f'{ident(name)} = {{ {body} }};')
    return ident(name)
files = sorted((ROOT / 'FieldGuide').glob('*.swift'))
refs, builds = [], []
for f in files:
    refs.append(obj('ref:'+f.name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(f.name)}; sourceTree = "<group>";'))
    builds.append(obj('build:'+f.name, f'isa = PBXBuildFile; fileRef = {refs[-1]};'))
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = FieldGuide.app; sourceTree = BUILT_PRODUCTS_DIR;')
appgroup = obj('appgroup', f'isa = PBXGroup; children = ({",".join(refs)},); path = FieldGuide; sourceTree = "<group>";')
products = obj('products', f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
main = obj('main', f'isa = PBXGroup; children = ({appgroup},{products},); sourceTree = "<group>";')
sources = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0;')
frameworks = obj('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
resources = obj('resources', 'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
projectconfigs, targetconfigs = [], []
for config in ['Debug','Release']:
    projectconfigs.append(obj('project:'+config, f'isa = XCBuildConfiguration; name = {config}; buildSettings = {{ CLANG_ENABLE_MODULES = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; }};'))
    targetconfigs.append(obj('target:'+config, f'''isa = XCBuildConfiguration; name = {config}; buildSettings = {{
    PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = com.example.FieldGuide;
    INFOPLIST_FILE = FieldGuide/Info.plist; GENERATE_INFOPLIST_FILE = NO;
    SWIFT_VERSION = 5.0; SWIFT_OPTIMIZATION_LEVEL = {q('-Onone' if config == 'Debug' else '-O')};
    TARGETED_DEVICE_FAMILY = 1; CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = "";
    CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 0.1.0;
    SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SUPPORTS_MACCATALYST = NO;
    LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
    }};'''))
pl = obj('projectlist', f'isa = XCConfigurationList; buildConfigurations = ({",".join(projectconfigs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
tl = obj('targetlist', f'isa = XCConfigurationList; buildConfigurations = ({",".join(targetconfigs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {tl}; buildPhases = ({sources},{frameworks},{resources},); buildRules = (); dependencies = (); name = FieldGuide; productName = FieldGuide; productReference = {product}; productType = "com.apple.product-type.application";')
project = obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {pl}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
folder = ROOT / 'FieldGuide.xcodeproj'
folder.mkdir(exist_ok=True)
(folder / 'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {project}; }}\n')
plist = {'CFBundleDisplayName':'FieldGuide', 'CFBundleExecutable':'$(EXECUTABLE_NAME)', 'CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleInfoDictionaryVersion':'6.0', 'CFBundleName':'$(PRODUCT_NAME)', 'CFBundlePackageType':'APPL', 'CFBundleShortVersionString':'$(MARKETING_VERSION)', 'CFBundleVersion':'$(CURRENT_PROJECT_VERSION)', 'LSRequiresIPhoneOS':True, 'UILaunchScreen':{}, 'UIApplicationSceneManifest': {'UIApplicationSupportsMultipleScenes':False}, 'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait'], 'NSCameraUsageDescription':'Use the camera to place practice guidance in your surroundings. Camera images are not uploaded.', 'UIRequiredDeviceCapabilities':['arm64']}
(ROOT / 'FieldGuide/Info.plist').write_bytes(plistlib.dumps(plist))
scheme = folder / 'xcshareddata/xcschemes'; scheme.mkdir(parents=True, exist_ok=True)
(scheme/'FieldGuide.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="FieldGuide.app" BlueprintName="FieldGuide" ReferencedContainer="container:FieldGuide.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="FieldGuide.app" BlueprintName="FieldGuide" ReferencedContainer="container:FieldGuide.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated FieldGuide.xcodeproj')
