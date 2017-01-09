//
//  SqlUtil.h
//  Booth
//
//  Created by James Howard on 4/26/15.
//
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

int SqlBindString(sqlite3_stmt *stmt, NSString *str, int pos);
int SqlBindData(sqlite3_stmt *stmt, NSData *data, int pos);

NSString *SqlReadString(sqlite3_stmt *stmt, int pos);
NSData *SqlReadData(sqlite3_stmt *stmt, int pos);

sqlite3_stmt *SqlPrepare(sqlite3 *db, NSString *str);

