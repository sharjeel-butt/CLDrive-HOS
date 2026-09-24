import { webview } from '@kit.ArkWeb';
import {
  MOBILE_USER_AGENT,
  OnboardingViewModel,
  ProviderOption,
  STEP_SELECT_PROVIDER
} from '../viewmodels/OnboardingViewModel';
import { ProviderIcon } from '../components/ProviderIcon';

@Entry
@Component
struct OnboardingPage {
  @State vm: OnboardingViewModel = new OnboardingViewModel();
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    this.vm.init();
  }

  build() {
    Column() {
      this.buildHeader()

      if (this.vm.step === STEP_SELECT_PROVIDER) {
        this.buildProviderSelection()
      } else {
        this.buildAuthView()
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      left: 24,
      right: 24,
      top: 24,
      bottom: 24
    })
    .backgroundColor('#F5F5F7')
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  @Builder
  buildHeader() {
    Column({ space: 8 }) {
      Row() {
        if (this.vm.isAddMode && this.vm.step === STEP_SELECT_PROVIDER) {
          Button('‹ Cancel')
            .backgroundColor(Color.Transparent)
            .fontColor('#0078D4')
            .fontSize(15)
            .padding(0)
            .onClick(() => {
              this.vm.onCancel();
            })
          Blank()
        }
      }
      .width('100%')

      Text(this.vm.isAddMode ? 'Add Account' : 'Welcome to CLDrive')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
      Text(this.vm.step === STEP_SELECT_PROVIDER
        ? 'Choose a cloud provider to get started'
        : `Sign in to ${this.vm.providerLabel(this.vm.selectedProvider)}`)
        .fontSize(14)
        .fontColor('#666')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ top: 24, bottom: 32 })
  }

  // ---------------------------------------------------------------------------
  // Step 1 — provider selection
  // ---------------------------------------------------------------------------

  @Builder
  buildProviderSelection() {
    Column({ space: 12 }) {
      ForEach(this.vm.providers, (item: ProviderOption) => {
        this.buildProviderCard(item)
      }, (item: ProviderOption) => item.type)
    }
    .width('100%')
  }

  @Builder
  buildProviderCard(item: ProviderOption) {
    Row({ space: 16 }) {
      ProviderIcon({ provider: item.type, iconSize: 48 })

      Column({ space: 4 }) {
        Text(item.label)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(item.enabled ? '#000000' : '#999999')
        Text(item.subtitle)
          .fontSize(13)
          .fontColor(item.enabled ? '#666666' : '#AAAAAA')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (item.enabled) {
        Text('›').fontSize(28).fontColor('#999999')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .opacity(item.enabled ? 1.0 : 0.6)
    .onClick(() => {
      if (item.enabled) {
        this.vm.onSelectProvider(item.type);
      }
    })
  }

  // ---------------------------------------------------------------------------
  // Step 2 — WebView authentication
  // ---------------------------------------------------------------------------

  @Builder
  buildAuthView() {
    Column() {
      Row() {
        Button('‹ Back')
          .backgroundColor(Color.Transparent)
          .fontColor('#0078D4')
          .fontSize(15)
          .padding(0)
          .onClick(() => {
            this.vm.onBack();
          })
        Blank()
      }
      .width('100%')
      .margin({ bottom: 12 })

      if (this.vm.authUrl.length > 0) {
        Web({ src: this.vm.authUrl, controller: this.controller })
          .userAgent(MOBILE_USER_AGENT)
          .onLoadIntercept((event) => {
            const url: string = event.data.getRequestUrl();

            // OneDrive redirect
            if (url.startsWith('https://cl.drive/oauth')) {
              this.vm.handleRedirect(url);
              return true;
            }

            // Google Drive loopback redirect
            if (url.startsWith('http://127.0.0.1:8080/oauth2redirect')
              || url.startsWith('http://localhost:8080/oauth2redirect')) {
              this.vm.handleRedirect(url);
              return true;
            }

            return false;
          })
          .domStorageAccess(true)
          .javaScriptAccess(true)
          .fileAccess(false)
          .onlineImageAccess(true)
          .mixedMode(MixedMode.All)
          .width('100%')
          .layoutWeight(1)
          .borderRadius(12)
          .backgroundColor(Color.White)
      } else {
        Column({ space: 12 }) {
          LoadingProgress().width(36).height(36)
          Text('Preparing sign-in...').fontSize(13).fontColor('#666666')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }

      if (this.vm.isLoading) {
        Row({ space: 12 }) {
          LoadingProgress().width(20).height(20)
          Text('Completing sign-in...').fontSize(14).fontColor('#666666')
        }
        .margin({ top: 16 })
      }

      if (this.vm.statusMessage.length > 0) {
        Text(this.vm.statusMessage)
          .fontSize(13)
          .fontColor('#D32F2F')
          .margin({ top: 16 })
          .textAlign(TextAlign.Center)
          .width('100%')
      }
    }
    .width('100%')
    .layoutWeight(1)
  }
}