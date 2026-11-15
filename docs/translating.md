# Translating the Seiran app

English strings live in `app/src/main/res/values/strings.xml`. Anything missing
from a translation falls back to English.

1. Copy `values/strings.xml` to `app/src/main/res/values-<lang>/strings.xml`
   (for example `values-in` for Indonesian, `values-pt-rBR` for Brazilian
   Portuguese) and translate the text only. Keep the `name=` keys, format
   placeholders such as `%1$s`, and technical names (vorpal, zstdn_o, adios).
2. Add the language tag (for example `"id"`) to `TAGS` in `LocaleHelper.kt`.
3. Open a pull request.
