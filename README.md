# NOPIXEL-INSPİREDHUD
<img width="1919" height="1079" alt="image" src="https://github.com/user-attachments/assets/7ba6ce80-e114-49d9-9b3a-3e3686c9187b" />

ox_inventory/data/items.lua add item.
```
['nitrous'] = {
    label = 'Nitrous Oxide (NOS)',
    weight = 1200, -- Gram cinsinden ağırlık (1.2 kg)
    stack = true,
    close = true,
    description = 'Yüksek performanslı NOS tüpü. Araca ekstra hız kazandırır.',
    client = {
        image = 'nitrous.png', -- ox_inventory/web/images içine atılacak görsel adı
        usetime = 3000,        -- Kullanım süresi (milisaniye cinsinden 3 saniye)
    }
},
```
