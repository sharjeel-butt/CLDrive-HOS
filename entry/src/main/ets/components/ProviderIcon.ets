import { CloudProviderType } from '../core/models/CloudProviderType';

interface ProviderStyle {
  glyph: string;
  color: string;
}

export function styleForProvider(type: CloudProviderType): ProviderStyle {
  if (type === CloudProviderType.ONEDRIVE) {
    return { glyph: '☁', color: '#0078D4' };
  }
  if (type === CloudProviderType.GOOGLE_DRIVE) {
    return { glyph: '▲', color: '#4285F4' };
  }
  if (type === CloudProviderType.DROPBOX) {
    return { glyph: '◆', color: '#0061FF' };
  }
  return { glyph: '☁', color: '#666666' };
}

@Component
export struct ProviderIcon {
  @Prop provider: CloudProviderType = CloudProviderType.ONEDRIVE;
  @Prop iconSize: number = 34;
  @Prop rounded: boolean = false;
  @Prop bgColor: string = '';

  build() {
    if (this.provider === CloudProviderType.ONEDRIVE) {
      this.buildBrandIcon($r('app.media.provider_onedrive'))
    } else if (this.provider === CloudProviderType.GOOGLE_DRIVE) {
      this.buildBrandIcon($r('app.media.provider_googledrive'))
    } else if (this.provider === CloudProviderType.DROPBOX) {
      this.buildBrandIcon($r('app.media.provider_dropbox'))
    } else {
      this.buildGlyphBadge()
    }
  }

  @Builder
  buildBrandIcon(source: Resource) {
    Column() {
      Image(source)
        .width(this.iconSize * 0.68)
        .height(this.iconSize * 0.68)
        .objectFit(ImageFit.Contain)
        .draggable(false)
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .borderRadius(this.rounded ? this.iconSize / 2 : this.iconSize * 0.235)
    .backgroundColor(
      this.bgColor.length > 0 ? this.bgColor : '#FFFFFF'
    )
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .clip(true)
  }

  @Builder
  buildGlyphBadge() {
    Column() {
      Text(styleForProvider(this.provider).glyph)
        .fontSize(this.iconSize * 0.53)
        .fontColor(Color.White)
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .borderRadius(this.rounded ? this.iconSize / 2 : this.iconSize * 0.235)
    .backgroundColor(
      this.bgColor.length > 0
        ? this.bgColor
        : styleForProvider(this.provider).color
    )
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .clip(true)
  }
}