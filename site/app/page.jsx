const download = '/downloads/ShellCove-0.1.0.dmg';

function Mark() {
  return (
    <svg className="brand-mark" viewBox="120 103 274 326" aria-hidden="true" focusable="false">
      <path d="M381 107 H203 C158 107 124 141 124 186 V317 C124 338 130 357 142 371 L188 371 C174 357 166 343 166 317 V186 C166 165 181 150 203 150 H381 C386 150 390 146 390 141 V116 C390 111 386 107 381 107 Z" fill="currentColor" />
      <path d="M237 230 L263 251 L237 272" fill="none" stroke="currentColor" strokeWidth="19" strokeLinejoin="round" strokeLinecap="round" />
      <path d="M283 275 H308" fill="none" stroke="currentColor" strokeWidth="19" strokeLinecap="round" />
      <path d="M143 379 C189 400 232 383 273 367 C315 351 352 348 389 363 L389 400 C340 385 310 396 268 411 C215 428 176 416 143 379 Z" fill="var(--accent)" />
    </svg>
  );
}

function ServerRow({ name, sub, env, label, on }) {
  return (
    <div className={`sc-row${on ? ' is-on' : ''}`}>
      <span className={`sc-dot sc-dot--${env}`} />
      <span className="sc-row__text">
        <b>{name}</b>
        <em>{sub}</em>
      </span>
      <span className={`sc-chip sc-chip--${env}`}>{label}</span>
    </div>
  );
}

function AppWindow() {
  return (
    <div className="ly-piece sc-win" aria-hidden="true">
      <div className="sc-bar">
        <span className="sc-dots"><i /><i /><i /></span>
        <img className="sc-appicon" src="/favicon.svg" alt="" width="14" height="14" loading="lazy" />
        <span className="sc-title">ShellCove</span>
        <span className="sc-sp" />
        <span className="sc-kbd">⌘K</span>
      </div>
      <div className="sc-body">
        <div className="sc-side">
          <div className="sc-search"><span>搜索服务器</span><span className="sc-kbd">⌘K</span></div>
          <p className="sc-group">生产<span>2</span></p>
          <ServerRow name="api-prod-01" sub="10.0.3.21 · deploy" env="prod" label="生产" on />
          <ServerRow name="db-prod-02" sub="10.0.3.44 · ubuntu" env="prod" label="生产" />
          <p className="sc-group">测试<span>1</span></p>
          <ServerRow name="api-stage-01" sub="10.1.3.12 · deploy" env="stage" label="测试" />
        </div>
        <div className="sc-detail">
          <div className="sc-head">
            <div>
              <p className="sc-name">api-prod-01</p>
              <p className="sc-meta">生产 · 10.0.3.21 · deploy</p>
            </div>
            <span className="sc-connect">连接</span>
          </div>
          <p className="sc-label">用途说明</p>
          <p className="sc-note">对外 API。重启前先在负载均衡摘掉本机，日志在 <code>/var/log/svc/api.log</code>。</p>
          <dl className="sc-facts">
            <div><dt>系统</dt><dd>Ubuntu 24.04</dd></div>
            <div><dt>到期</dt><dd>2027-03-01</dd></div>
            <div><dt>标签</dt><dd>API、跳板机</dd></div>
          </dl>
          <p className="sc-label">最近连接</p>
          <div className="sc-log"><span>11 月 10 日 22:41</span><span>26 分钟</span><span className="sc-ok">退出码 0</span></div>
          <div className="sc-log sc-log--second"><span>11 月 9 日 09:12</span><span>3 分钟</span><span className="sc-bad">连接中断</span></div>
        </div>
      </div>
    </div>
  );
}

export default function Page() {
  return (
    <>
      <header className="nav nav--centre">
        <div className="wrap nav__bar">
          <a className="skip-link" href="#top">跳到正文</a>
          <a className="nav__logo" href="#top"><Mark />ShellCove</a>
          <nav className="nav__links" aria-label="主导航">
            <div className="nav__item nav__item--demo"><a className="nav__link" href="#demo">试用</a></div>
            <div className="nav__item"><a className="nav__link" href="#environments">环境</a></div>
            <div className="nav__item"><a className="nav__link" href="#connect">连接</a></div>
            <div className="nav__item"><a className="nav__link" href="#local">本地</a></div>
            <div className="nav__item"><a className="nav__link" href="#questions">问题</a></div>
          </nav>
          <div className="nav__actions">
            <a className="btn btn--primary" href={download}>下载 macOS 版</a>
          </div>
          <button className="nav__toggle" type="button" aria-expanded="false" aria-label="菜单">
            <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden="true"><path d="M2 5h14M2 13h14" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" /></svg>
          </button>
        </div>
      </header>

      <main id="top">
        <section className="hero hero--centred" data-enter aria-labelledby="hero-h">
          <div className="wrap">
            <div className="hero-text">
              <div className="hero__c">
                <p className="pill"><span>版本 0.1.0</span><span className="muted">macOS 26 或更新</span></p>
                <h1 id="hero-h"><span className="hero-os">macOS </span>开发者的<br />服务器资料库</h1>
                <p className="hero__lead">左栏按环境列出你手上的 5 到 50 台机器，右栏写清用途和负责人；点「连接」，终端就在右栏打开，不用先翻记录。</p>
                <div className="btn-row">
                  <a className="btn btn--primary" href={download}>下载 macOS 版</a>
                  <a className="btn btn--secondary" href="#flow">看看怎么用</a>
                </div>
              </div>
              <div className="hero__window ui ui-mock" role="img" aria-label="ShellCove 主窗口：左栏按环境列出服务器，右栏是 api-prod-01 的用途说明、基础信息与最近连接">
                <AppWindow />
              </div>
            </div>
          </div>
        </section>

        <section className="section" id="demo" aria-labelledby="demo-h">
          <div className="wrap">
            <div className="section-head">
              <h2 id="demo-h">先在这里连一次</h2>
              <p className="sc-demo-lead">点左栏换机器，按「连接」看终端在原位打开；⌘K 搜索任意一台。</p>
            </div>
            <div className="sc-demo" role="group" aria-label="ShellCove 可交互原型">
              <iframe src="/prototype.html?embed=1" title="ShellCove 可交互原型" width="1280" height="540" sandbox="allow-scripts allow-forms" allow="clipboard-write" tabIndex={-1} />
            </div>
          </div>
        </section>

        <section className="section" id="flow" aria-labelledby="flow-h">
          <div className="wrap">
            <div className="section-head">
              <h2 id="flow-h">从记住一台机器到连上它</h2>
              <p>新增时写下用途，此后每次连接都从这份清单出发，不用再回忆 IP、端口和跳板机。</p>
            </div>
            <div className="grid sc-flow">
              <ol className="sc-steps span-5">
                <li>
                  <div className="sc-step__head"><span className="step-num">1</span><h3>新增一台服务器</h3></div>
                  <p>填名称、主机、端口和用户，再选环境与分组。</p>
                </li>
                <li>
                  <div className="sc-step__head"><span className="step-num">2</span><h3>写清它的用途</h3></div>
                  <p>用途说明支持 Markdown：重启前注意什么、日志在哪。</p>
                </li>
                <li>
                  <div className="sc-step__head"><span className="step-num">3</span><h3>点连接</h3></div>
                  <p>SSH Key 或密码都行，密码存进系统钥匙串。</p>
                </li>
              </ol>
              <div className="span-6 start-7">
                <div className="panel sc-panel ui ui-mock" role="img" aria-label="ShellCove 的新增服务器表单，已填写 redis-cache-01 的地址、环境与用途说明">
                  <div className="sc-win sc-win--flat" aria-hidden="true">
                    <div className="sc-bar">
                      <span className="sc-dots"><i /><i /><i /></span>
                      <img className="sc-appicon" src="/favicon.svg" alt="" width="14" height="14" loading="lazy" />
                      <span className="sc-title">新增服务器</span>
                      <span className="sc-sp" />
                      <span className="sc-kbd">未保存</span>
                    </div>
                    <div className="sc-form">
                      <label>名称<span className="sc-input">redis-cache-01</span></label>
                      <div className="sc-two">
                        <label>主机<span className="sc-input">10.0.4.18</span></label>
                        <label>端口<span className="sc-input">22</span></label>
                      </div>
                      <div className="sc-two">
                        <label>用户<span className="sc-input">deploy</span></label>
                        <label>环境<span className="sc-input"><span className="sc-chip sc-chip--dev">开发</span></span></label>
                      </div>
                      <label>用途说明<span className="sc-area">内存使用率 82%，扩容评审中。重启前先在群里说一声。</span></label>
                      <div className="sc-actions"><span className="sc-btn">保存</span><span className="sc-btn2">取消</span></div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="section" id="environments" aria-labelledby="environments-h">
          <div className="wrap">
            <div className="section-head">
              <h2 id="environments-h">生产、测试、开发，颜色先说话</h2>
              <p>环境标签在列表、详情和搜索里都是同一个颜色，生产机器是红的，连之前就知道在动什么。</p>
              <p className="sc-more"><a className="link" href="#questions">看连接记录</a></p>
            </div>
            <div className="grid">
              <article className="card card--open span-4">
                <h3>列表里先看环境</h3>
                <p>分组在上、机器在下；标签筛选只留下你要动的那一组。</p>
                <div className="panel sc-panel-sc ui ui-mock" role="img" aria-label="按环境分组的服务器列表，生产、测试、开发各有自己的颜色">
                  <div className="sc-mini" aria-hidden="true">
                    <ServerRow name="api-prod-01" sub="10.0.3.21" env="prod" label="生产" on />
                    <ServerRow name="db-prod-02" sub="10.0.3.44" env="prod" label="生产" />
                    <ServerRow name="api-stage-01" sub="10.1.3.12" env="stage" label="测试" />
                    <ServerRow name="dev-box" sub="10.2.0.7" env="dev" label="开发" />
                  </div>
                </div>
              </article>
              <article className="card card--open span-4">
                <h3>⌘K 搜索服务器</h3>
                <p>输入名字、IP、标签或用途里的词，回车打开详情。</p>
                <div className="panel sc-panel-sc ui ui-mock" role="img" aria-label="ShellCove 的搜索面板，输入 redis 后列出 redis-cache-01 和它的用途说明">
                  <div className="sc-pal" aria-hidden="true">
                    <div className="sc-pal__input"><span className="sc-caret">redis</span></div>
                    <div className="sc-pal__row is-on"><span>redis-cache-01</span><span className="sc-chip sc-chip--dev">开发</span></div>
                    <div className="sc-pal__row"><span>redis-cache-01 · 内存使用率 82%</span><span className="sc-dim">用途</span></div>
                    <div className="sc-pal__row"><span>dev-box · 跳板机</span><span className="sc-dim">开发</span></div>
                  </div>
                </div>
              </article>
              <article className="card card--open span-4">
                <h3>连接记录会留下来</h3>
                <p>每次连接的开始、时长和退出码都记一条，事后能回溯。</p>
                <div className="panel sc-panel-sc ui ui-mock" role="img" aria-label="ShellCove 的连接记录：api-prod-01 今天连接 26 分钟，db-prod-02 昨天连接 3 分钟。">
                  <div className="sc-mini" aria-hidden="true">
                    <div className="sc-mini__head"><span className="sc-term__name"><img className="sc-appicon" src="/favicon.svg" alt="" width="14" height="14" loading="lazy" />连接记录</span><span className="sc-kbd">全部</span></div>
                    <div className="sc-log"><span>api-prod-01</span><span>今天 22:41</span><span className="sc-ok">26 分钟</span></div>
                    <div className="sc-log"><span>db-prod-02</span><span>昨天 09:12</span><span className="sc-bad">3 分钟 · 中断</span></div>
                    <div className="sc-log"><span>api-stage-01</span><span>11 月 9 日</span><span className="sc-ok">12 分钟</span></div>
                  </div>
                </div>
              </article>
            </div>
          </div>
        </section>

        <section
          className="section ground-inverse"
          id="connect"
          aria-labelledby="connect-h"
        >
          <div className="wrap">
            <div className="grid sc-connect-row">
              <div className="span-5">
                <h2 id="connect-h">连接不另开窗口</h2>
                <p className="t-lead">点「连接」，终端接管右侧面板；开始和结束各记一条，带时间和退出码。</p>
                <dl className="sc-session">
                  <div><dt>本次连接</dt><dd>00:26</dd></div>
                  <div><dt>退出码</dt><dd>0</dd></div>
                  <div><dt>连接记录</dt><dd>已写入</dd></div>
                </dl>
              </div>
              <div className="span-6 start-7">
                <div className="sc-term ui ui-mock" role="img" aria-label="ShellCove 的终端面板，已连上 api-prod-01 并查看日志，底部显示已连接 26 分钟、退出码 0">
                  <div className="sc-term__bar"><span className="sc-term__name"><img className="sc-appicon" src="/favicon.svg" alt="" width="14" height="14" loading="lazy" />api-prod-01</span><span className="sc-dim">SSH · 已连接</span></div>
                  <div className="sc-term__body" aria-hidden="true">
                    <p><span className="sc-prompt">$</span> ssh deploy@10.0.3.21</p>
                    <p className="sc-dim">~$ tail -f /var/log/svc/api.log</p>
                    <p className="sc-dim">2026-11-10T22:41:07Z GET /health 200 3ms</p>
                    <p className="sc-dim">2026-11-10T22:41:09Z POST /v1/jobs 201 41ms</p>
                    <p className="sc-dim">2026-11-10T22:41:12Z GET /v1/jobs/8842 200 7ms</p>
                    <p className="sc-dim">2026-11-10T22:41:15Z POST /v1/jobs 201 38ms</p>
                    <p className="sc-dim">2026-11-10T22:41:18Z GET /health 200 2ms</p>
                    <p className="sc-dim">2026-11-10T22:41:21Z GET /v1/jobs/8842 200 6ms</p>
                    <p className="sc-dim">2026-11-10T22:41:24Z POST /v1/jobs 201 44ms</p>
                    <p className="sc-dim">2026-11-10T22:41:27Z GET /health 200 3ms</p>
                    <p className="sc-dim">2026-11-10T22:41:31Z GET /v1/jobs 200 9ms</p>
                    <p className="sc-dim">2026-11-10T22:41:34Z POST /v1/jobs 201 40ms</p>
                    <p className="sc-dim">2026-11-10T22:41:38Z GET /health 200 2ms</p>
                    <p className="sc-dim">2026-11-10T22:41:41Z GET /v1/jobs/8851 200 5ms</p>
                    <p className="sc-dim">2026-11-10T22:41:44Z GET /health 200 2ms</p>
                    <p className="sc-dim">2026-11-10T22:41:47Z POST /v1/jobs 201 39ms</p>
                    <p className="sc-dim">2026-11-10T22:41:51Z GET /v1/jobs/8851 200 4ms</p>
                    <p className="sc-dim">2026-11-10T22:41:54Z GET /health 200 3ms</p>
                    <p className="sc-dim">2026-11-10T22:41:57Z POST /v1/jobs 201 42ms</p>
                    <p className="sc-dim">2026-11-10T22:42:01Z GET /v1/jobs 200 8ms</p>
                    <p className="sc-dim">2026-11-10T22:42:04Z GET /health 200 2ms</p>
                    <p className="sc-dim">2026-11-10T22:42:07Z POST /v1/jobs 201 37ms</p>
                    <p><span className="sc-prompt">~$</span> <span className="sc-cursor" /></p>
                  </div>
                  <div className="sc-term__foot"><span>已连接 00:26</span><span>退出码 0</span></div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="section" id="local" aria-labelledby="local-h">
          <div className="wrap">
            <div className="section-head sc-statement" data-moment="liquid-type">
              <h2 id="local-h" className="mo-lt__type">数据只留在这台 Mac 上</h2>
              <p>不用注册，也不会上传。服务器资料存在本机，密码交给系统钥匙串，私钥只记路径；除 SSH 外没有别的出站请求。</p>
            </div>
            <div className="grid sc-local">
              <dl className="sc-facts-row span-6">
                <div><dt>账号</dt><dd>不需要</dd></div>
                <div><dt>服务器资料</dt><dd>本机数据库</dd></div>
                <div><dt>密码</dt><dd>系统钥匙串</dd></div>
                <div><dt>出站请求</dt><dd>只有 SSH</dd></div>
              </dl>
              <div className="span-6 start-7 sc-limit">
                <h3>明确不做</h3>
                <ul className="rows">
                  <li><span className="rows__name">iCloud 同步</span><span className="rows__value">不做</span></li>
                  <li><span className="rows__name">私钥托管</span><span className="rows__value">只记路径</span></li>
                  <li><span className="rows__name">SFTP 与文件传输</span><span className="rows__value">不做</span></li>
                </ul>
              </div>
            </div>
          </div>
        </section>

        <section className="section" id="questions" aria-labelledby="questions-h">
          <div className="wrap">
            <div className="section-head">
              <h2 id="questions-h">常见问题</h2>
            </div>
            <div className="grid">
              <div className="faq sc-faq span-6">
                <div className="faq__item">
                  <h3>支持哪些 macOS 版本？</h3>
                  <p>macOS 26 或更新。窗口跟随系统的深浅色、强调色和键盘快捷键。</p>
                </div>
                <div className="faq__item">
                  <h3>数据存在哪里？</h3>
                  <p>本机数据库；密码在系统钥匙串；私钥只记路径。</p>
                </div>
                <div className="faq__item">
                  <h3>会同步到其他设备吗？</h3>
                  <p>不会。没有账号、没有 iCloud 同步，也没有服务端。</p>
                </div>
                <div className="faq__item">
                  <h3>能管理多少台服务器？</h3>
                  <p>5 到 50 台。左栏分组、标签筛选和 ⌘K 搜索都按这个量级设计。</p>
                </div>
                <div className="faq__item">
                  <h3>支持 SFTP 或端口转发吗？</h3>
                  <p>首个版本不做；端口转发写在 <code>~/.ssh/config</code> 里，连接时自动带上。</p>
                </div>
              </div>
              <div className="span-6 start-7">
                <div className="sc-mini ui ui-mock" role="img" aria-label="ShellCove 的连接记录：api-prod-01 今天连接 26 分钟，db-prod-02 昨天连接 3 分钟。">
                  <div className="sc-mini__head"><span className="sc-term__name"><img className="sc-appicon" src="/favicon.svg" alt="" width="14" height="14" loading="lazy" />连接记录</span><span className="sc-kbd">全部</span></div>
                  <div className="sc-log"><span>api-prod-01</span><span>今天 22:41</span><span className="sc-ok">26 分钟</span></div>
                  <div className="sc-log"><span>db-prod-02</span><span>昨天 09:12</span><span className="sc-bad">3 分钟 · 中断</span></div>
                  <div className="sc-log"><span>api-stage-01</span><span>11 月 9 日</span><span className="sc-ok">12 分钟</span></div>
                  <div className="sc-log"><span>dev-box</span><span>11 月 8 日</span><span className="sc-ok">41 分钟</span></div>
                  <div className="sc-log"><span>db-prod-02</span><span>11 月 7 日</span><span className="sc-ok">2 小时</span></div>
                  <div className="sc-log"><span>api-prod-01</span><span>11 月 6 日</span><span className="sc-bad">18 分钟 · 中断</span></div>
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>

      <footer className="footer closing footer--dark ground-inverse" id="contact" aria-labelledby="close-h">
        <div className="wrap">
          <div className="closing__cta close--type">
            <div className="section-head">
              <h2 id="close-h">下载 macOS 版</h2>
              <p>版本 0.1.0，支持 macOS 26 或更新。</p>
            </div>
            <a className="btn btn--primary btn--xl btn--wide" href={download}>
              下载 macOS 版
              <svg className="m-arrow" viewBox="0 0 12 12" aria-hidden="true"><path className="m-arrow__stem" d="M1 6h8" /><path className="m-arrow__head" d="M4.5 2.5 8 6l-3.5 3.5" /></svg>
            </a>
            <p className="close__name" aria-hidden="true">ShellCove</p>
          </div>
          <div className="closing__links">
            <div className="grid">
              <div className="span-4 stack-4">
                <a className="nav__logo" href="#top"><Mark />ShellCove</a>
                <p className="footer__lede">服务器资料库，点一下就连上。</p>
              </div>
              <div className="span-2 footer__col">
                <h3>功能</h3>
                <ul><li><a href="#flow">流程</a></li><li><a href="#environments">环境</a></li></ul>
              </div>
              <div className="span-2 footer__col">
                <h3>连接</h3>
                <ul><li><a href="#connect">原位终端</a></li><li><a href="#local">本机数据</a></li></ul>
              </div>
              <div className="span-2 footer__col">
                <h3>说明</h3>
                <ul><li><a href="#questions">常见问题</a></li><li><a href="#questions">系统要求</a></li></ul>
              </div>
              <div className="span-2 footer__col">
                <h3>下载</h3>
                <ul><li><a href={download}>下载 macOS 版</a></li></ul>
              </div>
            </div>
            <div className="footer__legal">
              <span>© 2026 ShellCove</span>
            </div>
          </div>
        </div>
      </footer>

      <nav className="actionbar" aria-label="下载">
        <a className="btn btn--primary" href={download}>下载 macOS 版</a>
      </nav>
    </>
  );
}
