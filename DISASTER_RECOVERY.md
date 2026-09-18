# Mobilis 障害復旧手順書

本番環境で予約・顧客・回数券データに問題が起きた場合の手順です。

> [!CAUTION]
> `pg:backups:restore` は復元先データベースの全データを削除してから復元します。
> 一人で判断して実行せず、対象アプリ名・バックアップID・復元時点を二重確認してください。

## 前提

- Herokuアプリ名: `mobilis`
- 本番DB: `DATABASE_URL`
- 公開ヘルスチェック: `https://mobilis-8008d58dd542.herokuapp.com/health/booking`
- Heroku CLIへログイン済みであること
- コマンドはMacのターミナルで実行すること

## 1. まず影響範囲を確認する

```bash
heroku ps --app mobilis
heroku releases --app mobilis
heroku logs --tail --app mobilis
```

別のブラウザで次も確認します。

1. ヘルスチェックが `{"status":"ok"}` を返すか
2. 公開予約画面を開けるか
3. 管理画面へログインできるか
4. 直前にデプロイ、設定変更、データ操作をしていないか

アプリ再起動だけで直る可能性がある場合は、DB復元より先に次を試します。

```bash
heroku restart --app mobilis
```

## 2. バックアップを確認する

```bash
heroku pg:info --app mobilis
heroku pg:backups --app mobilis
heroku pg:backups:schedules --app mobilis
```

復元候補のバックアップID、作成日時、状態が `Completed` であることを確認します。

```bash
heroku pg:backups:info <BACKUP_ID> --app mobilis
```

最新バックアップが障害発生後に作られている場合、壊れたデータを含む可能性があります。障害発生前のバックアップを選びます。

## 3. 現在のDBを必ず退避する

復元操作の直前に、現在の状態を手動バックアップします。

```bash
heroku pg:backups:capture DATABASE_URL --app mobilis
heroku pg:backups --app mobilis
```

新しいバックアップが `Completed` になったことを確認し、そのIDを記録します。調査用にPCへ保存する場合は次を実行します。

```bash
heroku pg:backups:download <NEW_BACKUP_ID> --app mobilis
```

`latest.dump` には顧客の個人情報が含まれます。共有フォルダへ置かず、安全な場所で保管し、不要になったら削除してください。

## 4. 復元の最終確認

実行前に、次の3点を声に出して確認します。

- 復元先は本番アプリ `mobilis` の `DATABASE_URL`
- 復元元 `<BACKUP_ID>` は障害発生前に作成され、状態が `Completed`
- 手順3で現在のDBを退避済み

予約受付を一時停止できない構成では、バックアップ作成時点以降の新しい予約が復元によって失われます。該当時間帯のメールとGoogleカレンダーを控え、復元後に照合してください。

## 5. 本番DBを復元する

ここから先は破壊的操作です。`<BACKUP_ID>` を実際のID（例: `b123`）に置き換えます。

```bash
heroku pg:backups:restore <BACKUP_ID> DATABASE_URL --app mobilis
```

Herokuが確認を求めたら、画面に表示されたアプリ名が `mobilis` であることを確認してから入力します。

完了状態を確認します。

```bash
heroku pg:backups --app mobilis
heroku pg:info --app mobilis
```

## 6. 復元後にアプリを整える

現在のコードに必要なDB更新を適用し、アプリを再起動します。

```bash
heroku run bundle exec rails db:migrate --app mobilis
heroku restart --app mobilis
```

データ整合性チェックを実行します。

```bash
heroku run bundle exec rails data_integrity:check --app mobilis
```

`[DATA INTEGRITY] ok` が表示されれば、検査上の異常はありません。問題が報告された場合は、対象IDを控えてから管理画面で確認します。

## 7. 動作を確認する

次の順序で確認します。

1. `/health/booking` がHTTP 200と `{"status":"ok"}` を返す
2. 管理画面へログインできる
3. 直近の予約件数と内容が妥当
4. 顧客と回数券が表示される
5. Googleカレンダーの予定と予約が一致する
6. 公開予約画面で空き状況を表示できる
7. テスト予約を1件作成し、確認メールが1通だけ届く
8. テスト予約を削除またはキャンセルする

バックアップ作成時点以降の予約は、確認メールとGoogleカレンダーから特定し、必要に応じて管理画面から再登録します。

## 8. 復旧記録を残す

最低限、次を記録します。個人情報は記載しません。

- 発生日時と復旧日時
- 症状
- 原因
- 使用したバックアップIDと作成日時
- 失われた可能性がある時間帯
- 再登録した予約ID
- 再発防止策

## 復元せずに相談するケース

- 原因や障害発生時刻が分からない
- 正しいバックアップを判断できない
- バックアップが `Completed` ではない
- DBではなくアプリコードや外部サービスの問題と思われる
- 復元すると失われる予約を把握できない

この場合は復元コマンドを実行せず、Herokuログのrequest ID、発生日時、画面のエラー内容を確認してから対応します。

## 参考

- [Heroku PGBackups](https://devcenter.heroku.com/articles/heroku-postgres-backups)
