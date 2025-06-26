# 藍芽圖片資料交換通訊協定

此文件用以設計一套適用於透過藍芽SSP，用於圖片傳輸的傳輸協定設計



## 一、檔案傳輸協定

### 封包格式

```
| HEADER | TYPE | FILE ID | INDEX | LENGTH | DATA | CHECKSUM |
```

| **欄位**  | **長度** | **說明**                                                     |
| --------- | -------- | ------------------------------------------------------------ |
| HEADER    | 2 bytes  | 0xAA 0x55                                                    |
| TYPE      | 1 byte   | 封包類型（見下表）                                           |
| INDEX     | 2 bytes  | 封包序號（從 0 開始）                                        |
| LENGTH    | 2 bytes  | DATA 長度（最大 1024 或視實作限制）                          |
| DATA      | n bytes  | 真正圖片資料（raw binary / JPEG 等）                         |
| CHECK SUM | 2 bytes  | 將[HEADER, TYPE, INDEX, LENGTH, DATA] 資料每個bytes互加後最右側之2 bytes值 |

#### TYPE 封包類型定義

| **值** | **名稱**   | **用途說明**                           |
| ------ | ---------- | -------------------------------------- |
| 0x01   | START      | 開始封包，攜帶總圖檔大小與封包數       |
| 0x02   | DATA       | 資料封包，實際圖片資料分段             |
| 0x03   | END        | 結尾封包，表示資料傳送完畢             |
| 0x04   | ACK        | 回應封包，確認接收成功                 |
| 0x05   | RESEND_REQ | 要求補傳某幾段 INDEX（用 DATA 帶索引） |







## 二、圖片傳輸流程



```mermaid
flowchart TD
    Start([START])
    Data0([DATA0])
    Data1([DATA1])
    Dots([...])
    End([END])
    Ack([ACK 回應])
    Resend([RESEND_REQ（若有缺）])

    Start --> Data0 --> Data1 --> Dots --> End
    End --> Resend
    Ack -.-> Start
```





### 傳送端傳輸流程（Sender，例如 Android)

1. 將圖片壓縮成 JPEG
2. 計算總大小、分段數量（如每包 512 bytes）
3. 發送 START
4. 依序發送每個 DATA 封包
5. 發送 END
6. 監聽是否有 RESEND_REQ，補傳指定 index



### 接收端流程（Receiver，例如 MCU)

1. 接收 START，準備緩衝區
2. 接收 DATA 封包並驗證 CRC
3. 若校驗失敗或缺包，記錄 INDEX
4. 收到 END 後比對是否完整
5. 回傳 RESEND_REQ 若有缺包
6. 資料完整後合併為圖檔



## 三、資料結構

### START 封包格式（TYPE = 0x01）

```
結構：| HEADER[2] | TYPE[1] | FILE ID[2] | INDEX[2] | LENGTH[2] | DATA[14] | CHECKSUM[2] |
範例：| 0xAA 0x55 | 0x01 | 0x0000 | 0x0008 | [DATA: 12 bytes] | CHECKSUM |
```

DATA 內容如下：

```
結構：|FILE LENGTH[4] | CHUNKS NUMBER[4] | FILE POSTFIX[4] |
```



**FILE LENGTH**: 要傳輸的資料長度有多少bytes

**CHUNKS NUMBER**: 資料切分成多少個 chunk數量。例如每512 bytes資料切成一個chuck，則有一個3000 bytes長度的資料會被切分爲 6個 chunk

**FILE ID** : 每個檔案有自己的整數ID，當檔案風包缺漏時，以FILE ID 和 INDEX 來找到缺漏的封包

**FILE POSTFIX**：檔案副檔名如jpg, png. 用以方便辨識檔案型別



### DATA 封包格式 (TYPE = 0x02)

```
結構：| HEADER[2] | TYPE[1] | FILE ID[2] | INDEX[2] | LENGTH[2] | DATA[14] | CHECKSUM[2] |
範例：| HEADER | 0x02 | 0x0000 | 0x0200 | [DATA: 512 bytes] | CHECKSUM |
```

DATA 內容為切分成chunk的資料

### END 封包格式 (TYPE = 0x03)

```
結構：| HEADER[2] | TYPE[1] | FILE ID[2] | INDEX[2] | LENGTH[2] | DATA[14] | CHECKSUM[2] |
範例：| HEADER | 0x03 | 0x0000 | 0x0000 | [DATA: 0 bytes] | CHECKSUM |
```

### ACK 封包（TYPE = 0x04）

```
結構：| HEADER[2] | TYPE[1] | FILE ID[2] | INDEX[2] | LENGTH[2] | DATA[14] | CHECKSUM[2] |
範例：| HEADER | 0x04 | 0x0000 | 0x0002 | 0x00 0x02 | CHECKSUM | // ACK index 2
```

### RESEND（TYPE = 0x05）

```
結構：| HEADER[2] | TYPE[1] | FILE ID[2] | INDEX[2] | LENGTH[2] | DATA[14] | CHECKSUM[2] |
範例：| HEADER | 0x05 | 0x0000 | 0x0002 | 0x00 0x02 | CHECKSUM | //請求重送 index 2

```

