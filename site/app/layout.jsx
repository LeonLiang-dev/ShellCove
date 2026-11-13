import Boot from './boot';

export const metadata = {
  metadataBase: new URL('https://shellcove.example'),
  title: 'ShellCove：macOS 上的服务器资料库与一键连接',
  description:
    '把每台服务器的用途、环境和负责人记在一个窗口里，选中机器就能在原地连上。原生 macOS 应用，数据只存在本机。',
  openGraph: {
    type: 'website',
    title: 'ShellCove：macOS 上的服务器资料库与一键连接',
    description:
      '把每台服务器的用途、环境和负责人记在一个窗口里，选中机器就能在原地连上。原生 macOS 应用，数据只存在本机。',
    images: ['/share.jpg'],
  },
  twitter: {
    card: 'summary_large_image',
  },
  icons: { icon: '/favicon.svg' },
  themeColor: '#0c0e10',
};

const enter = "document.documentElement.classList.add('m-enter');setTimeout(()=>document.documentElement.classList.add('m-enter-done'),700)";
const moments = "document.documentElement.classList.add('mo-js');setTimeout(()=>document.documentElement.classList.add('mo-safe'),2500)";

export default function RootLayout({ children }) {
  return (
    <html lang="zh-CN" data-type="software" data-radius="soft" data-buttons="pill" data-motion>
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
        <meta name="site-kind" content="software" />
        <meta name="page-type" content="software" />
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Geist:wght@400..600&family=Geist+Mono:wght@400..500&display=optional"
          rel="stylesheet"
        />
        <link
          href={`https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;500&display=optional&text=${"%E3%80%81%E3%80%82%E3%80%8C%E3%80%8D%E4%B8%80%E4%B8%8A%E4%B8%8B%E4%B8%8D%E4%B8%8E%E4%B8%AA%E4%B8%AD%E4%B8%B2%E4%B8%BB%E4%B9%88%E4%B9%8B%E4%B9%9F%E4%BA%8B%E4%BA%9B%E4%BA%A4%E4%BA%A7%E4%BA%BA%E4%BB%80%E4%BB%8A%E4%BB%8E%E4%BB%96%E4%BB%B6%E4%BB%BD%E4%BC%9A%E4%BC%A0%E4%BD%8D%E4%BD%8F%E4%BD%A0%E4%BD%BF%E4%BE%A7%E4%BF%9D%E5%81%9A%E5%85%88%E5%85%A5%E5%85%A8%E5%85%B6%E5%86%85%E5%86%8C%E5%86%8D%E5%86%99%E5%87%BA%E5%88%86%E5%88%97%E5%88%AB%E5%88%B0%E5%89%8D%E5%8A%9F%E5%8A%A1%E5%8A%A8%E5%8C%99%E5%8D%95%E5%8E%9F%E5%8F%91%E5%8F%96%E5%8F%A3%E5%8F%A6%E5%8F%AA%E5%8F%B0%E5%8F%B3%E5%8F%B7%E5%90%84%E5%90%8C%E5%90%8D%E5%90%8E%E5%90%97%E5%90%AF%E5%92%8C%E5%93%AA%E5%99%A8%E5%9B%9E%E5%9C%A8%E5%9C%B0%E5%9D%87%E5%A1%AB%E5%A2%83%E5%A2%9E%E5%A3%B0%E5%A4%87%E5%A4%96%E5%A4%9A%E5%A4%A9%E5%A7%8B%E5%AD%97%E5%AD%98%E5%AE%83%E5%AE%A1%E5%AE%B9%E5%AF%86%E5%AF%B9%E5%B0%8F%E5%B0%91%E5%B0%B1%E5%B7%A6%E5%B7%B2%E5%B8%A6%E5%B8%B8%E5%BA%93%E5%BC%80%E5%BC%BA%E5%BD%95%E5%BE%84%E5%BF%86%E5%BF%97%E5%BF%AB%E6%80%8E%E6%83%85%E6%84%8F%E6%88%96%E6%88%B7%E6%89%8B%E6%89%93%E6%89%98%E6%89%A9%E6%8C%81%E6%8C%89%E6%8D%AE%E6%8D%B7%E6%8E%89%E6%8E%A5%E6%90%9C%E6%91%98%E6%94%AF%E6%95%B0%E6%96%87%E6%96%99%E6%96%AD%E6%96%B0%E6%97%A5%E6%97%B6%E6%98%8E%E6%98%A8%E6%98%AF%E6%9B%B4%E6%9C%80%E6%9C%88%E6%9C%89%E6%9C%8D%E6%9C%9F%E6%9C%AA%E6%9C%AC%E6%9C%BA%E6%9D%9F%E6%9D%A1%E6%9D%A5%E6%9D%BF%E6%A0%87%E6%A0%8F%E6%A0%B7%E6%AC%A1%E6%AD%A3%E6%AD%A4%E6%AD%A5%E6%AF%8F%E6%B1%82%E6%B2%A1%E6%B3%A8%E6%B5%81%E6%B5%85%E6%B5%8B%E6%B6%88%E6%B7%B1%E6%B8%85%E6%BA%AF%E7%82%B9%E7%89%88%E7%8E%87%E7%8E%AF%E7%90%86%E7%94%9F%E7%94%A8%E7%95%99%E7%9A%84%E7%9B%98%E7%9C%8B%E7%9F%A5%E7%A0%81%E7%A1%AE%E7%A7%81%E7%A7%B0%E7%A8%8B%E7%AA%97%E7%AB%99%E7%AB%AF%E7%AD%9B%E7%AD%BE%E7%AE%A1%E7%B3%BB%E7%B4%A2%E7%BA%A2%E7%BA%A7%E7%BB%84%E7%BB%88%E7%BB%93%E7%BB%99%E7%BB%9F%E7%BE%A4%E7%BF%BB%E8%80%85%E8%83%BD%E8%87%AA%E8%89%B2%E8%A1%8C%E8%A1%A1%E8%A1%A8%E8%A6%81%E8%A7%81%E8%AE%A1%E8%AE%B0%E8%AE%BE%E8%AF%84%E8%AF%8D%E8%AF%95%E8%AF%9D%E8%AF%A6%E8%AF%B4%E8%AF%B7%E8%B0%83%E8%B4%9F%E8%B4%A3%E8%B4%A6%E8%B5%84%E8%B7%9F%E8%B7%AF%E8%B7%B3%E8%BD%A6%E8%BD%AC%E8%BD%BD%E8%BE%93%E8%BF%91%E8%BF%99%E8%BF%9B%E8%BF%9E%E9%80%80%E9%80%89%E9%80%94%E9%81%93%E9%82%A3%E9%83%A8%E9%83%BD%E9%87%8C%E9%87%8D%E9%87%8F%E9%92%9F%E9%92%A5%E9%94%AE%E9%95%BF%E9%97%AE%E9%97%B4%E9%99%A4%E9%9A%8F%E9%9C%80%E9%9D%A2%E9%A2%98%E9%A2%9C%E9%A6%96%EF%BC%8C%EF%BC%9A%EF%BC%9B%EF%BC%9F"}`}
          rel="stylesheet"
        />
        <link rel="stylesheet" href="/assets/system.css" />
        <link rel="stylesheet" href="/assets/ui/cards.css" />
        <link rel="stylesheet" href="/assets/motion/motion.css" />
        <link rel="stylesheet" href="/assets/backgrounds/backgrounds.css" />
        <link rel="stylesheet" href="/assets/layout/layout.css" />
        <link rel="stylesheet" href="/assets/icons/icon.css" />
        <style
          dangerouslySetInnerHTML={{
            __html: `
:root {
  --p-bg: #0c0e10; --p-surface: #14181b; --p-ink: #f1f2f4; --p-muted: #8a9199;
  --p-accent: #3ecfbf; --p-accent-ink: #0c0e10; --p-action: #3ecfbf; --p-action-ink: #0c0e10;
  --p-inv-bg: #f1f2f4; --p-inv-surface: #dee0e2; --p-inv-ink: #0c0e10; --p-inv-muted: #585a5c;
  --p-inv-accent: #0c0e10; --p-inv-accent-ink: #f1f2f4; --p-inv-action: #0c0e10; --p-inv-action-ink: #f1f2f4;
  --font-display: "Geist", "Noto Sans SC", system-ui, sans-serif;
  --font-text: "Geist", "Noto Sans SC", system-ui, sans-serif;
  --font-mono: "Geist Mono", ui-monospace, "SFMono-Regular", Menlo, Consolas, monospace;
  --display-weight: 500;
  --display-tracking: -0.035em;
  --display-tracking-xl: -0.045em;
}
`,
          }}
        />
        <link rel="stylesheet" href="/site.css" />
        <link rel="stylesheet" href="/assets/moments/liquid-type/moment.css" />
        <script dangerouslySetInnerHTML={{ __html: enter }} />
        <script dangerouslySetInnerHTML={{ __html: moments }} />
        <link rel="modulepreload" href="/assets/moments/moments.js" />
        <link rel="modulepreload" href="/assets/moments/lib.js" />
        <link rel="modulepreload" href="/assets/moments/liquid-type/moment.js" />
      </head>
      <body>
        {children}
        <Boot />
      </body>
    </html>
  );
}
