//
//  SqlUtil.m
//  Booth
//
//  Created by James Howard on 4/26/15.
//
//

#import "SqlUtil.h"

int SqlBindString(sqlite3_stmt *stmt, NSString *str, int pos) {
    if (!str) {
        return sqlite3_bind_null(stmt, pos);
    } else {
        return sqlite3_bind_text(stmt, pos, [str UTF8String], (int)(strlen([str UTF8String])), SQLITE_TRANSIENT);
    }
}

int SqlBindData(sqlite3_stmt *stmt, NSData *data, int pos) {
    if (!data) {
        return sqlite3_bind_null(stmt, pos);
    } else {
        return sqlite3_bind_blob(stmt, pos, [data bytes], (int)[data length], SQLITE_TRANSIENT);
    }
}

NSString *SqlReadString(sqlite3_stmt *stmt, int pos) {
    const unsigned char *s = sqlite3_column_text(stmt, pos);
    return s ? [NSString stringWithUTF8String:(const char *)s] : nil;
}

NSData *SqlReadData(sqlite3_stmt *stmt, int pos) {
    const unsigned char *d = sqlite3_column_blob(stmt, pos);
    int len = sqlite3_column_bytes(stmt, pos);
    if (!d) return nil;
    return [NSData dataWithBytes:d length:(NSUInteger)len];
}

sqlite3_stmt *SqlPrepare(sqlite3 *db, NSString *str) {
    const char *sql = [str UTF8String];
    int sqlLen = (int)strlen(sql);
    sqlite3_stmt *stmt = NULL;
    int result = sqlite3_prepare_v2(db, sql, sqlLen, &stmt, NULL);
    if (result != SQLITE_OK) {
        NSLog(@"Could not prepare: %@. %d (%s)",
              str, result, sqlite3_errmsg(db));
    }
    return stmt;
}
