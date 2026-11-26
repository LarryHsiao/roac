# Roäc 首次安裝後的設定

Roäc 是一隻停在桌面上的渡鴉。你問，他讀你自己的 markdown 筆記來回答。
他靠本機的 Claude Code CLI 作答，所以先把 CLI 備好，再設定他。

## 1. 準備 Claude Code CLI

先依 Claude Code 官方說明安裝 `claude`，在終端機執行一次 `claude` 完成登入。

**macOS**：Roäc 透過 `zsh -lc` 啟動 CLI。這是 login shell，會讀 `~/.zprofile`，
但不讀 `~/.zshrc`。用下面這行確認 Roäc 找得到 CLI：

```sh
env -i HOME="$HOME" /bin/zsh -lc 'command -v claude'
```

有印出路徑就好。沒有任何輸出，請把 `claude` 所在目錄的 `PATH` 設定寫進
`~/.zprofile`。

**Windows**：Roäc 直接從 `PATH` 執行 `claude`，不經過 shell。在新開的
PowerShell 確認：

```powershell
Get-Command claude
```

## 2. 啟動 Roäc

開啟 Roäc 後，渡鴉會浮在其他視窗之上並四處走動。Dock 和工作列上沒有他的圖示。

- 點渡鴉：打開對話泡泡。
- 若跳出更新視窗，那是自動更新檢查。

## 首次啟動引導

全新安裝第一次啟動時，引導會自動出現，依序檢查 `claude`、選筆記資料夾、
開始提問。可以隨時略過；完成或略過後不再出現。中途關掉泡泡不算完成，
點渡鴉會再看到它。用過舊版的人升級後不會看到。

引導只檢查第 1 步的 `claude` 找不找得到，並完成第 4 步的選資料夾。登入狀態與其他選項照下面設定。

## 3. 打開設定

以下的按鈕與欄位名稱以繁體中文介面為準；其他系統語言顯示英文。

點渡鴉，再點提問欄旁的齒輪圖示。macOS 在泡泡開著時也可以按 `⌘,`。
按 `Esc` 關閉設定。

## 4. 選筆記資料夾

在「筆記」按「選擇…」，選一個放 markdown 筆記的資料夾。選完立即生效。

沒有選的話，預設是家目錄下的 `Minerva`（Windows 是
`%USERPROFILE%\Minerva`）。

## 5. 選用項目

### Claude 設定

只有一套 Claude Code 設定的人不用改，欄位會顯示「CLI 本身的設定」。

若你用多個設定目錄（例如 `~/.claude-personal`），在這裡選定。那個目錄要先登入過：

```sh
CLAUDE_CONFIG_DIR="$HOME/.claude-personal" claude
```

Windows（PowerShell）：

```powershell
$env:CLAUDE_CONFIG_DIR="$HOME\.claude-personal"; claude
```

資料夾選擇視窗若看不到以 `.` 開頭的目錄，macOS 可按 `⌘⇧.` 顯示隱藏項目。

### 角色包與角色

內建的手繪渡鴉不需要任何角色包。要換角色：

1. 把角色包的 `.zip` 放進角色包資料夾。macOS 預設是
   `~/Library/Application Support/roac/packs`，Windows 預設是
   `%APPDATA%\roac\packs`。資料夾不存在就自己建立。
2. 重新啟動 Roäc，讓清單讀到新檔案。
3. 在「角色」下拉選單選它。

沒有指定角色時，Roäc 會穿上資料夾裡依檔名排序的第一個角色包。
此時下拉選單仍顯示「Roäc（手繪）」。

因此資料夾裡只要有角色包，在選單選「Roäc（手繪）」並不會換回手繪渡鴉。
要換回來，請把資料夾裡的 `.zip` 移走，再重新啟動。

### 可寫入

預設關閉，狀態是「僅供閱讀」。打開後，Roäc 可以修改筆記資料夾內的檔案，
也可以執行 `printf` 與 `/handoff` 的腳本。後者需要作者個人的 Claude 設定庫
skadi，沒有安裝就用不到。

開啟前請知道：筆記資料夾的限制只管檔案編輯工具。`printf` 指令本身可以用
重新導向寫到資料夾以外的地方。細節見
[README 的 Letting Roäc act](../README.md#letting-roäc-act)。

## 6. 試問一題

回到泡泡，問一件你筆記裡寫過的事。答案會逐字出現。
接著追問會延續同一段對話；關掉泡泡就重新開始。

## 基本操作

| 動作 | 效果 |
|---|---|
| 拖曳渡鴉 | 移動位置，稍後會繼續走動 |
| 點渡鴉 | 開啟或關閉泡泡 |
| 右鍵點渡鴉 | 固定在原地；再點一次解除 |
| `Esc` | 先關設定，再關泡泡 |
| 點答案中的連結 | 用瀏覽器開啟；打不開時複製網址 |

## 結束 Roäc

目前沒有結束按鈕。macOS：

```sh
pkill -x roac
```

Windows（PowerShell）：

```powershell
Stop-Process -Name roac
```

## 常見問題

**回答時說找不到 `claude`。**
回到第 1 步確認 `PATH`。Windows 若是用 npm 安裝，指令檔是 `claude.cmd`，
直接啟動時可能找不到；可改用官方的原生安裝版。此點尚未實測。

**回答時出現登入或認證錯誤。**
在終端機執行 `claude` 重新登入。有指定「Claude 設定」時，要帶同一個
`CLAUDE_CONFIG_DIR` 登入（見第 5 步）。

**泡泡說筆記資料夾不見了。**
打開設定，重新選一個存在的資料夾。

**設定面板顯示設定檔打不開、不是 JSON，或裡頭放的不是一組設定。**
修好設定檔後重新啟動 Roäc。位置：

- macOS：`~/Library/Application Support/roac/config.json`
- Windows：`%APPDATA%\roac\config.json`

Windows 上若舊版已經在
`\Library\Application Support\roac\`（目前磁碟根目錄，或 `HOME` 之下）
寫過檔案，而新位置還沒有，Roäc 會沿用舊位置。
注意：在面板改任何一項，都會重寫這個檔案，原本讀不了的內容會全部遺失。
想保留就先備份。

**面板改了設定卻沒有生效。**
看欄位下方的來源說明。顯示「由 ROAC_… 指定」代表環境變數優先於面板設定。

**Roäc 很久沒回應就放棄了。**
CLI 連續 90 秒沒有任何輸出時，Roäc 會停止等待。
