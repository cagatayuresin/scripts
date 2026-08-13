# 04-ollama-lab

Yerel Ollama kurulumu için envanter, disk analizi, sağlık ve hız testleri.
`llm-rm`/`llm-purge` dışındaki hedefler **salt okunur**; silme hedefleri onay ister.

```bash
make llm-list      # modeller: yerel/cloud, boyut, bellekte olanlar
make llm-disk      # GERÇEK disk kullanımı (paylaşılan katmanları çözer)
make llm-smoke     # Ollama ayakta mı, model yanıt veriyor mu
make llm-bench     # soğuk başlangıç, ilk token gecikmesi, token/s
make llm-embed     # embedding boyutu ve gecikme (RAG için)

make llm-rm LLM_MODELS="qwen3:14b qwen3:14b-64k"   # seçili modelleri sil
make llm-purge                                      # tüm yerel modelleri sil
```

Silme hedefleri `DRY=1` ile denenebilir ve **gerçek** kazancı gösterir: tek varyantı
silmek çoğu zaman 0 GB kazandırır, ailenin tamamını silmek gerekir.

`llm-disk` neden önemli: `ollama list` 72 GB gösterirken diskte 30 GB olabilir —
aynı modelin varyantları (`:20b`, `:20b-32k`, `:20b-64k`) katmanları paylaşır.
Modül "bu modeli silersen kaç GB kazanırsın" sorusunu doğru cevaplar (çoğu zaman: sıfır).

| Değişken | Varsayılan | Anlamı |
|:--|:--|:--|
| `LLM_HOST` | `http://localhost:11434` | Ollama adresi |
| `LLM_MODEL` | otomatik | En küçük yerel üretim modeli seçilir |
| `LLM_TOKENS` | `64` | `llm-bench` token sayısı |

📖 Tam kılavuz: <https://cagatayuresin.github.io/scripts/04_ollama-lab>
