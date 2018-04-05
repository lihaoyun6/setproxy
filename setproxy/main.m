#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
// A library for parsing command line.
// https://github.com/stephencelis/BRLOptionParser
#import "BRLOptionParser.h"

#define setproxyVersion @"1.7.5"

int main(int argc, const char * argv[])
{
    NSString* mode;
    NSString* URL;
    NSString* portString;
    
    BRLOptionParser *options = [BRLOptionParser new];
    [options setBanner:@"用法: %s [-m pac|socks|http|https|off] [-s <PAC文件地址/代理服务器地址>] [-p <端口>]", argv[0]];
    
    // Mode
    [options addOption:"mode" flag:'m' description:@"代理模式, 可以是下列其中之一: pac,socks,http,https,off" argument:&mode];
    [options addOption:"server" flag:'s' description:@"pac模式下用于设置PAC文件地址, 其他模式中用于设置代理服务器地址" argument:&URL];
    [options addOption:"port" flag:'p' description:@"设置连接到代理服务器的端口" argument:&portString];
    
    NSMutableSet* networkServiceKeys = [NSMutableSet set];
    //[options addOption:"network-service" flag:'n' description:@"Manual specify the network interfaces need to set proxy." blockWithArgument:^(NSString* value){
    //    [networkServiceKeys addObject:value];
    //}];
    
    NSMutableSet* proxyExceptions = [NSMutableSet set];
    [options addOption:"proxy-exception" flag:'x' description:@"设置要忽略代理设置的例外域名/地址" blockWithArgument:^(NSString *value) {
        [proxyExceptions addObject:value];
    }];
    
    // Help
    __weak typeof(options) weakOptions = options;
    [options addOption:"help" flag:'h' description:@"显示此帮助信息" block:^{
        printf("%s", [[weakOptions description] UTF8String]);
        exit(EXIT_SUCCESS);
    }];
    
    // Version
    [options addOption:"version" flag:'v' description:@"显示版本信息" block:^{
        printf("%s\n", [setproxyVersion UTF8String]);
        exit(EXIT_SUCCESS);
    }];
    
    NSError *error = nil;
    if (![options parseArgc:argc argv:argv error:&error]) {
        const char * message = error.localizedDescription.UTF8String;
        fprintf(stderr, "%s: %s\n", argv[0], message);
        exit(EXIT_FAILURE);
    }
    
    if (mode) {
        if ([@"pac" isEqualToString:mode]) {
            if (!URL) {
                printf("错误: 没有指定PAC文件地址, 请使用 \"-s\" 选项来设置\n");
                return 1;
            }
        } else if ([@"socks" isEqualToString:mode]) {
            if (!URL) {
                printf("错误: 没有指定代理服务器地址, 请使用 \"-s\" 选项来设置\n");
                return 1;
            } else if (!portString) {
                printf("错误: 没有指定代理服务器端口, 请使用 \"-p\" 选项来设置\n");
                return 1;
            }
        } else if ([@"http" isEqualToString:mode]) {
            if (!URL) {
                printf("错误: 没有指定代理服务器地址, 请使用 \"-s\" 选项来设置\n");
                return 1;
            } else if (!portString) {
                printf("错误: 没有指定代理服务器端口, 请使用 \"-p\" 选项来设置\n");
                return 1;
            }
        } else if ([@"https" isEqualToString:mode]) {
            if (!URL) {
                printf("错误: 没有指定代理服务器地址, 请使用 \"-s\" 选项来设置\n");
                return 1;
            } else if (!portString) {
                printf("错误: 没有指定代理服务器端口, 请使用 \"-p\" 选项来设置\n");
                return 1;
            }
        } else if (![@"off" isEqualToString:mode]) {
            printf("错误: 对于选项 \"-m\" 来说 \"%s\" 是一个无效的参数\n", [mode UTF8String]);
            //printf("%s", [[weakOptions description] UTF8String]);
            return 1;
        }
    } else {
        printf("%s", [[weakOptions description] UTF8String]);
        exit(EXIT_SUCCESS);
    }
    
    NSInteger port = 0;
    if (portString) {
        port = [portString integerValue];
        if (0 == port) {
            return 1;
        }
    }
    
    static AuthorizationRef authRef;
    static AuthorizationFlags authFlags;
    authFlags = kAuthorizationFlagDefaults
    | kAuthorizationFlagExtendRights
    | kAuthorizationFlagInteractionAllowed
    | kAuthorizationFlagPreAuthorize;
    OSStatus authErr = AuthorizationCreate(nil, kAuthorizationEmptyEnvironment, authFlags, &authRef);
    if (authErr != noErr) {
        authRef = nil;
        NSLog(@"创建授权请求时出错");
        return 1;
    } else {
        if (authRef == NULL) {
            NSLog(@"未被授予修改网络配置的权限");
            return 1;
        }
        
        SCPreferencesRef prefRef = SCPreferencesCreateWithAuthorization(nil, CFSTR("setproxy"), nil, authRef);
        
        NSDictionary *sets = (__bridge NSDictionary *)SCPreferencesGetValue(prefRef, kSCPrefNetworkServices);
        
        NSMutableDictionary *proxies = [[NSMutableDictionary alloc] init];
        [proxies setObject:[NSNumber numberWithInt:0] forKey:(NSString *)kCFNetworkProxiesHTTPEnable];
        [proxies setObject:[NSNumber numberWithInt:0] forKey:(NSString *)kCFNetworkProxiesHTTPSEnable];
        [proxies setObject:[NSNumber numberWithInt:0] forKey:(NSString *)kCFNetworkProxiesProxyAutoConfigEnable];
        [proxies setObject:[NSNumber numberWithInt:0] forKey:(NSString *)kCFNetworkProxiesSOCKSEnable];
        [proxies setObject:@[] forKey:(NSString *)kCFNetworkProxiesExceptionsList];
        
        for (NSString *key in [sets allKeys]) {
            NSMutableDictionary *dict = [sets objectForKey:key];
            NSString *hardware = [dict valueForKeyPath:@"Interface.Hardware"];
             //       NSLog(@"%@", hardware);
            BOOL modify = NO;
            if ([networkServiceKeys count] > 0) {
                if ([networkServiceKeys containsObject:key]) {
                    modify = YES;
                }
            } else if ([hardware isEqualToString:@"AirPort"]
                       || [hardware isEqualToString:@"Wi-Fi"]
                       || [hardware isEqualToString:@"Ethernet"]) {
                modify = YES;
            }
            if (modify) {
                
                NSString* prefPath = [NSString stringWithFormat:@"/%@/%@/%@", kSCPrefNetworkServices
                                      , key, kSCEntNetProxies];
                
                if ([mode isEqualToString:@"pac"]) {
                    
                    [proxies setObject:URL forKey:(NSString *)kCFNetworkProxiesProxyAutoConfigURLString];
                    [proxies setObject:[NSNumber numberWithInt:1] forKey:(NSString *)kCFNetworkProxiesProxyAutoConfigEnable];
                    
                    SCPreferencesPathSetValue(prefRef, (__bridge CFStringRef)prefPath
                                              , (__bridge CFDictionaryRef)proxies);
                } else if ([mode isEqualToString:@"socks"]) {
                    
                    [proxies setObject:URL forKey:(NSString *)
                     kCFNetworkProxiesSOCKSProxy];
                    [proxies setObject:[NSNumber numberWithInteger:port] forKey:(NSString*)
                     kCFNetworkProxiesSOCKSPort];
                    [proxies setObject:[NSNumber numberWithInt:1] forKey:(NSString*)
                     kCFNetworkProxiesSOCKSEnable];
                    [proxies setObject:[proxyExceptions allObjects] forKey:(NSString *)kCFNetworkProxiesExceptionsList];
                    
                    SCPreferencesPathSetValue(prefRef, (__bridge CFStringRef)prefPath
                                              , (__bridge CFDictionaryRef)proxies);
                } else if ([mode isEqualToString:@"http"]) {
                    
                    [proxies setObject:URL forKey:(NSString *)
                     kCFNetworkProxiesHTTPProxy];
                    [proxies setObject:[NSNumber numberWithInteger:port] forKey:(NSString*)
                     kCFNetworkProxiesHTTPPort];
                    [proxies setObject:[NSNumber numberWithInt:1] forKey:(NSString*)
                     kCFNetworkProxiesHTTPEnable];
                    
                    SCPreferencesPathSetValue(prefRef, (__bridge CFStringRef)prefPath
                                              , (__bridge CFDictionaryRef)proxies);
                } else if ([mode isEqualToString:@"https"]) {
                    
                    [proxies setObject:URL forKey:(NSString *)
                     kCFNetworkProxiesHTTPSProxy];
                    [proxies setObject:[NSNumber numberWithInteger:port] forKey:(NSString*)
                     kCFNetworkProxiesHTTPSPort];
                    [proxies setObject:[NSNumber numberWithInt:1] forKey:(NSString*)
                     kCFNetworkProxiesHTTPSEnable];
                    
                    SCPreferencesPathSetValue(prefRef, (__bridge CFStringRef)prefPath
                                              , (__bridge CFDictionaryRef)proxies);
                } else if ([mode isEqualToString:@"off"]) {
                    if (URL != nil && portString != nil) {
                        NSDictionary* oldProxies
                        = (__bridge NSDictionary*)SCPreferencesPathGetValue(prefRef
                                                                            , (__bridge CFStringRef)prefPath);
                        
                        if (([oldProxies[(NSString *)kCFNetworkProxiesProxyAutoConfigURLString] isEqualToString:URL]
                             &&[oldProxies[(NSString *)kCFNetworkProxiesProxyAutoConfigEnable] isEqual:[NSNumber numberWithInt:1]])
                            ||([oldProxies[(NSString*)kCFNetworkProxiesSOCKSProxy] isEqualToString:URL]
                               &&[oldProxies[(NSString*)kCFNetworkProxiesSOCKSPort] isEqualTo:[NSNumber numberWithInteger:port]]
                               &&[oldProxies[(NSString*)kCFNetworkProxiesSOCKSEnable] isEqual:[NSNumber numberWithInt:1]])
                            ) {
                            SCPreferencesPathSetValue(prefRef, (__bridge CFStringRef)prefPath
                                                      , (__bridge CFDictionaryRef)proxies);
                        }
                    } else {
                        SCPreferencesPathSetValue(prefRef, (__bridge CFStringRef)prefPath
                                                  , (__bridge CFDictionaryRef)proxies);
                    }
                }
            }
        }
        
        SCPreferencesCommitChanges(prefRef);
        SCPreferencesApplyChanges(prefRef);
        SCPreferencesSynchronize(prefRef);
        
        AuthorizationFree(authRef, kAuthorizationFlagDefaults);
    }
    
    printf("已将代理模式设置为 %s\n", [mode UTF8String]);
    if ([@"pac" isEqualToString:mode]) {
        printf("%s\n", [URL UTF8String]);
    } else if (![@"off" isEqualToString:mode]) {
        printf("%s:%ld\n", [URL UTF8String], (long)port);
    }
    
    return 0;
}

