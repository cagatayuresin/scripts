---
title: "04 · ollama-lab"
parent: Script Kılavuzları
nav_order: 4
---

# 04-ollama-lab · Kullanım Kılavuzu

![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?style=flat&logo=gnubash&logoColor=white) ![GNU Make](https://img.shields.io/badge/GNU-Make-A42E2B?style=flat&logo=gnu&logoColor=white) ![Ollama](https://img.shields.io/badge/Ollama-yerel_LLM-000000?style=flat&logo=ollama&logoColor=white) ![jq](https://img.shields.io/badge/jq-JSON-2E7BB4?style=flat) ![Read-Only](https://img.shields.io/badge/T%C3%BCm_hedefler-salt_okunur-10B981?style=flat)

## Amaç

Yerel Ollama kurulumu için günlük araç seti: model envanteri, **gerçek** disk
kullanımı, sağlık testi ve hız ölçümü. LLM entegrasyonu geliştirirken "sorun benim
kodumda mı, Ollama'da mı?" sorusunu saniyeler içinde cevaplar.

`llm-list`, `llm-disk`, `llm-smoke`, `llm-bench` ve `llm-embed` **salt okunurdur** —
hiçbir şeyi değiştirmezler. Yalnızca `llm-rm` ve `llm-purge` silme yapar; ikisi de
önce ne kaybedeceğinizi gösterip onay ister ve `DRY=1` ile denenebilir.

## Make hedefleri

| Hedef | Açıklama |
|:--|:--|
| `make llm-list` | Kurulu modeller: yerel/cloud ayrımı, boyut, bellekte olanlar |
| `make llm-disk` | **Gerçek** disk kullanımı; paylaşılan katmanları çözer |
| `make llm-smoke` | Ollama ayakta mı, model yanıt veriyor mu (hızlı sağlık testi) |
| `make llm-bench` | Soğuk başlangıç, ilk token gecikmesi (TTFT), token/s |
| `make llm-embed` | Embedding ucu: vektör boyutu ve gecikme (RAG için) |
| `make llm-rm` | Seçili modelleri siler (`LLM_MODELS="ad1 ad2"`) |
| `make llm-purge` | **Tüm yerel modelleri** diskten siler |

## Parametreler

| Değişken | Varsayılan | Anlamı |
|:--|:--|:--|
| `LLM_HOST` | `http://localhost:11434` | Ollama adresi |
| `LLM_MODEL` | otomatik | Kullanılacak model; boşsa en küçük **yerel** üretim modeli seçilir |
| `LLM_EMBED_MODEL` | otomatik | Embedding modeli (adında `embed` geçen ilk yerel model) |
| `LLM_PROMPT` | `Bir cumleyle kendini tanit.` | `llm-bench` istemi |
| `LLM_TOKENS` | `64` | `llm-bench` için üretilecek token sayısı |

```bash
make llm-bench LLM_MODEL=qwen3:14b LLM_TOKENS=200
make llm-list LLM_HOST=http://192.168.1.50:11434
```

Cloud modeller (`:cloud` etiketli) otomatik seçimde **atlanır** — internet ve Ollama
hesabı gerektirdikleri için ölçümü yanıltırlar.

## `llm-disk` — neden gerekli?

`ollama list` her modelin yanına kendi boyutunu yazar. Ama aynı temel modelin
varyantları (örneğin farklı context uzunluğu için oluşturulmuş `:20b`, `:20b-32k`,
`:20b-64k`) diskteki **aynı katmanları paylaşır**. Bu yüzden listelenen boyutların
toplamı, gerçekte kaplanan yerden çok daha büyük görünür.

```text
  MODEL                         LISTELENEN    SILERSEN
  ------------------------------------------------------------
  gpt-oss:20b                     12.85 GB     0.00 GB
  gpt-oss:20b-32k                 12.85 GB     0.00 GB
  gpt-oss:20b-64k                 12.85 GB     0.00 GB
  qwen3:14b                        8.64 GB     0.00 GB
  qwen3:14b-64k                    8.64 GB     0.00 GB
  nomic-embed-text:latest          0.26 GB     0.26 GB
  ------------------------------------------------------------
  LISTELENEN TOPLAM               72.81 GB  <- ollama list toplami
  GERCEK DISK                     30.11 GB  <- diskte gercekten

  Ayni katmanlari paylasan aileler
     12.85 GB  ortak katman
            (3 varyant: gpt-oss:20b, gpt-oss:20b-32k, gpt-oss:20b-64k)
```

**`SILERSEN` sütunu asıl bilgidir:** `0.00 GB` yazan bir modeli silmek disk
kazandırmaz, çünkü katmanlarını başka varyantlar da kullanır. Yer açmak için ailenin
**tüm** varyantlarını silmeniz gerekir.

Analiz, model dizinindeki manifest dosyalarını okuyup katman özetlerini (digest)
benzersizleştirerek yapılır; Ollama'nın kendi çıktısı bu bilgiyi vermez.

### Manifest dizinine erişim

Ollama systemd servisi olarak çalışıyorsa modeller `/usr/share/ollama/.ollama/models`
altındadır ve `ollama` grubuna aittir. Erişemiyorsanız:

```bash
sudo usermod -aG ollama $USER   # sonrasında yeniden oturum açın
```

## `llm-bench` — iki çağrı neden?

```text
  CAGRI          YUKLEME      ILK TOKEN    HIZ            TOPLAM
──────────────────────────────────────────────────────────────────
  1. cagri       0.08 s       0.14 s       43.8 tok/s     0.92 s
  2. cagri       0.07 s       0.09 s       45.4 tok/s     0.83 s
```

- **YUKLEME:** Modelin diskten belleğe alınması. Model bellekte değilse bu değer
  saniyeler sürer (14B'lik bir model için 30 saniyeyi bulabilir), bellekteyse ~0.
- **ILK TOKEN (TTFT):** Yükleme + istemin işlenmesi. Kullanıcının ekranda ilk harfi
  görmesi için geçen süre.
- **HIZ:** Saf üretim hızı (`eval_count / eval_duration`).

İki çağrı yapılır çünkü ilk çağrı çoğu zaman soğuk başlangıcı içerir. Uygulamanızda
kullanıcının bu gecikmeyi yaşamaması için açılışta bir ısıtma (warm-up) isteği
göndermek yaygın bir çözümdür.

Ollama modeli varsayılan olarak **5 dakika** bellekte tutar (`keep_alive`); bu süre
sonunda bir sonraki istek yine soğuk olur.

## `llm-embed`

```text
  ✔ Vektor boyutu: 768
  1.         24 ms
  2.         19 ms
  3.         18 ms
  Ortalama   20 ms
```

Vektör boyutu, vektör veritabanınızda (pgvector, Qdrant, Chroma) tanımlayacağınız
boyutla birebir aynı olmalıdır — `nomic-embed-text` için 768.

## Model silme — `llm-rm` ve `llm-purge`

Silme, `llm-disk` ile aynı katman analizini kullanır: **listelenen boyutu değil, diskte
gerçekten boşalacak yeri** gösterir.

```bash
make llm-rm LLM_MODELS="qwen3:14b" DRY=1        # önce dene
make llm-rm LLM_MODELS="qwen3:14b qwen3:14b-64k" # ailenin tamamı
make llm-purge DRY=1                             # hepsi silinse ne olur?
make llm-purge                                   # tüm yerel modeller
```

Tek bir varyantı silmek genelde işe yaramaz:

```text
  SILINECEK MODEL                LISTELENEN
  gpt-oss:20b-32k                12.85 GB
  LISTELENEN TOPLAM              12.85 GB
  GERCEK KAZANC                  0.00 GB  <- diskte gercekten bosalacak

  ⚠ Gercek kazanc listelenen boyuttan dusuk: katmanlarin bir kismini
    silinmeyen baska modeller de kullaniyor.
```

Ailenin tamamını verirseniz gerçek kazanç ortaya çıkar:

```text
  gpt-oss:20b                    12.85 GB
  gpt-oss:20b-32k                12.85 GB
  gpt-oss:20b-64k                12.85 GB
  LISTELENEN TOPLAM              38.54 GB
  GERCEK KAZANC                  12.85 GB
```

Güvenlik davranışı:

- Silmeden önce tablo gösterilir ve **onay istenir** (`YES=1` ile atlanır).
- `DRY=1` tek bir model bile silmeden ne olacağını gösterir.
- Kurulu olmayan bir model adı verilirse hiçbir şey silinmez, hata döner.
- `llm-purge` yalnızca **yerel** modelleri hedefler; cloud modeller diskte yer
  kaplamadığı için kapsam dışıdır.
- Silinen modeller yeniden indirilmelidir — 30 GB'lık bir kütüphane için bu saatler
  sürebilir. Script bunu onay öncesi hatırlatır.

## Gereksinimler

| Araç | Not |
|:--|:--|
| `ollama` | Servis çalışır durumda: `systemctl status ollama` (silme için CLI de gerekir) |
| `curl` | API çağrıları |
| `jq` | JSON ayrıştırma (`sudo apt install jq`) |

## Sorun giderme

| Belirti | Çözüm |
|:--|:--|
| `Ollama'ya ulasilamadi` | `systemctl start ollama` veya `ollama serve` |
| `Manifest dizini okunamiyor` | `sudo usermod -aG ollama $USER`, sonra yeniden oturum açın |
| `Yerel model bulunamadi` | `ollama pull qwen2.5:3b` (küçük ve hızlı bir başlangıç modeli) |
| `llm-bench` çok uzun sürüyor | Model ilk kez yükleniyor; `LLM_TOKENS=32` ile kısaltın |
| Embedding boyutu beklenenden farklı | Farklı embedding modeli kullanıyorsunuz; `LLM_EMBED_MODEL` ile belirtin |
