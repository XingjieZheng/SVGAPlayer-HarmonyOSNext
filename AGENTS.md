# HarmonyOS NEXT (鸿蒙Next) 开发规范

> 本文档基于 HarmonyOS NEXT (API 12+) 官方开发指南、最佳实践和社区经验整理而成
> 更新日期：2026年3月

---

## 目录

1. [ArkTS 语言规范](#1-arkts-语言规范)
2. [命名规范](#2-命名规范)
3. [代码风格](#3-代码风格)
4. [应用架构规范](#4-应用架构规范)
5. [状态管理规范](#5-状态管理规范)
6. [UI 开发规范](#6-ui-开发规范)
7. [性能优化规范](#7-性能优化规范)
8. [安全开发规范](#8-安全开发规范)
9. [最佳实践总结](#9-最佳实践总结)

---

## 1. ArkTS 语言规范

### 1.1 基本语法原则

ArkTS 是 HarmonyOS 优选的主力应用开发语言，基于 TypeScript 扩展，强化了静态检查和分析能力。

**核心原则：**
- **强类型**：所有变量必须声明类型，禁止使用 `any` 类型
- **显式初始化**：变量必须显式初始化，不允许 `undefined` 和 `null` 的隐式使用
- **不可变性优先**：优先使用 `const`，必要时使用 `let`

**示例：**
```typescript
// ✅ 正确
const MAX_COUNT: number = 100;
let userName: string = '张三';
let isActive: boolean = false;
let userList: string[] = ['user1', 'user2'];

// ❌ 错误
let count;  // 未声明类型
let data: any;  // 禁止使用 any
```

### 1.2 类型声明规范

```typescript
// 接口定义
interface UserInfo {
  id: number;
  name: string;
  age?: number;  // 可选属性
  readonly createdAt: Date;  // 只读属性
}

// 类型别名
type Callback = (result: string) => void;
type UserType = 'admin' | 'user' | 'guest';

// 枚举定义
enum StatusCode {
  SUCCESS = 200,
  NOT_FOUND = 404,
  ERROR = 500
}

// 类定义
class UserManager {
  private users: UserInfo[] = [];
  
  addUser(user: UserInfo): void {
    this.users.push(user);
  }
  
  getUserById(id: number): UserInfo | undefined {
    return this.users.find(u => u.id === id);
  }
}
```

### 1.3 函数规范

```typescript
// 函数声明 - 必须明确返回值类型
function calculateTotal(price: number, quantity: number): number {
  return price * quantity;
}

// 箭头函数
const formatDate = (date: Date): string => {
  return date.toLocaleDateString('zh-CN');
};

// 异步函数
async function fetchUserData(userId: number): Promise<UserInfo> {
  const response = await http.request(`https://api.example.com/users/${userId}`);
  return response.data as UserInfo;
}

// 函数参数默认值
function greet(name: string, greeting: string = '你好'): string {
  return `${greeting}，${name}！`;
}
```

---

## 2. 命名规范

### 2.1 命名风格总览

| 类型 | 命名风格 | 示例 |
|------|---------|------|
| 类名 | UpperCamelCase (大驼峰) | `UserProfile`, `HttpRequest` |
| 接口名 | UpperCamelCase | `UserInfo`, `ApiResponse` |
| 枚举名 | UpperCamelCase | `StatusCode`, `ErrorType` |
| 命名空间 | UpperCamelCase | `AuthUtils`, `DataHelper` |
| 变量名 | lowerCamelCase (小驼峰) | `userName`, `totalCount` |
| 函数名 | lowerCamelCase | `getUserInfo()`, `calculatePrice()` |
| 参数名 | lowerCamelCase | `userId`, `options` |
| 常量名 | UPPER_SNAKE_CASE (全大写下划线) | `MAX_RETRY_COUNT`, `API_BASE_URL` |
| 枚举值 | UPPER_SNAKE_CASE | `SUCCESS`, `NOT_FOUND` |
| 文件名 | PascalCase | `UserService.ets`, `HomePage.ets` |

### 2.2 命名详细规则

**类名：**
- 使用名词或名词短语
- 避免使用动词或模糊词汇
- 表达清晰意图

```typescript
// ✅ 正确
class UserProfile { }
class NetworkManager { }
class DataRepository { }

// ❌ 错误
class Manage { }  // 太模糊
class DoSomething { }  // 动词开头
class user { }  // 小写开头
```

**变量名：**
- 使用有意义的英文单词
- 避免单字母（除循环变量 i, j, k）
- 布尔变量使用 `is`, `has`, `can` 前缀

```typescript
// ✅ 正确
let userName: string = '张三';
let isLoading: boolean = false;
let hasPermission: boolean = true;
let canEdit: boolean = false;
let itemCount: number = 0;

// ❌ 错误
let a: string;  // 无意义
let flg: boolean;  // 缩写不清晰
let load: boolean;  // 无 is/has/can 前缀
```

**函数名：**
- 使用动词或动词短语
- 表达函数执行的操作
- getter/setter 使用 `get`/`set` 前缀

```typescript
// ✅ 正确
function fetchUserData(): void { }
function calculateTotalPrice(): number { }
function validateInput(): boolean { }
function getUserName(): string { }
function setUserName(name: string): void { }

// ❌ 错误
function data(): void { }  // 名词
function do(): void { }  // 太模糊
function calc(): number { }  // 缩写不清晰
```

**常量名：**
- 全大写字母
- 单词间用下划线分隔
- 表达完整语义

```typescript
// ✅ 正确
const MAX_CONNECTION_TIMEOUT: number = 30000;
const API_BASE_URL: string = 'https://api.example.com';
const DEFAULT_PAGE_SIZE: number = 20;
const CACHE_EXPIRATION_MS: number = 3600000;

// ❌ 错误
const maxCount = 100;  // 小写
const timeout = 3000;  // 小写且不清晰
```

### 2.3 文件名规范

- ArkTS 文件使用 `.ets` 扩展名
- 文件名使用 PascalCase
- 文件名应与主要导出内容一致

```
✅ 正确：
- UserProfile.ets
- HttpRequestService.ets
- HomePage.ets
- LoginAbility.ets

❌ 错误：
- user-profile.ets  (使用连字符)
- user_profile.ets  (使用下划线)
- userprofile.ets   (无大写)
- home_page.ets     (混合风格)
```

---

## 3. 代码风格

### 3.1 缩进与格式

- **缩进**：使用 2 个空格（不要使用 Tab）
- **行长度**：单行最多 120 个字符
- **换行**：属性链式调用时每个属性换行

```typescript
// ✅ 正确 - 2空格缩进
@Component
struct UserCard {
  @State private isExpanded: boolean = false;
  
  build() {
    Column() {
      Text('用户信息')
        .fontSize(18)
        .fontColor('#333333')
        .fontWeight(FontWeight.Bold)
      Button('点击')
        .onClick(() => {
          this.isExpanded = !this.isExpanded;
        })
    }
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }
}
```

### 3.2 大括号规范

- 所有条件、循环、函数都使用大括号
- 左大括号不换行
- 即使只有一行代码也要使用大括号

```typescript
// ✅ 正确
if (isValid) {
  processData();
}

for (let i = 0; i < count; i++) {
  console.log(i);
}

function handleClick(): void {
  updateState();
}

// ❌ 错误
if (isValid) processData();  // 缺少大括号

if (isValid)
  processData();  // 即使单行也要有大括号
```

### 3.3 空行规范

```typescript
// 类/结构体定义前后空行
@Component
struct UserCard {
  
  // 1. 状态变量区域
  @State private isExpanded: boolean = false;
  @State private userName: string = '';
  
  // 2. 私有变量区域
  private cacheKey: string = 'user_cache';
  
  // 3. 构造函数
  constructor() {
    // 初始化逻辑
  }
  
  // 4. 生命周期回调
  aboutToAppear() {
    this.loadData();
  }
  
  // 5. 私有方法
  private loadData(): void {
    // 数据加载逻辑
  }
  
  // 6. 事件处理方法
  private handleClick(): void {
    this.isExpanded = !this.isExpanded;
  }
  
  // 7. build 方法
  build() {
    Column() {
      this.HeaderBuilder()
      if (this.isExpanded) {
        this.DetailBuilder()
      }
    }
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .shadow({ radius: 10, color: '#1F000000' })
  }
  
  // 6. @Builder 构建函数
  @Builder
  HeaderBuilder() {
    Row() {
      Image(this.DEFAULT_AVATAR)
        .width(48)
        .height(48)
        .borderRadius(24)
      
      Text(this.userName)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .onClick(() => this.handleExpand())
  }
  
  @Builder
  DetailBuilder() {
    Column() {
      Text(`Email: ${this.userData.email}`)
      Text(`Phone: ${this.userData.phone}`)
    }
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 12 })
  }
}
```

### 3.4 注释规范

**单行注释：**
```typescript
// 计算用户总积分
const totalPoints: number = this.calculatePoints();
```

**多行注释：**
```typescript
/*
 * 用户信息卡片组件
 * 用于展示用户基本信息和头像
 * 支持展开/收起功能
 */
@Component
struct UserCard {
  // ...
}
```

**文档注释：**
```typescript
/**
 * 获取用户信息
 * @param userId 用户ID
 * @param includeDetails 是否包含详细信息
 * @returns 用户信息对象，若不存在返回 undefined
 * @throws 网络请求失败时抛出异常
 * @example
 * const user = await getUserInfo(123, true);
 */
async function getUserInfo(
  userId: number, 
  includeDetails: boolean = false
): Promise<UserInfo | undefined> {
  // 实现
}
```

---

## 4. 应用架构规范

### 4.1 Stage 模型概述

Stage 模型是 HarmonyOS NEXT 主推且长期演进的应用模型，提供了：
- **AbilityStage**：HAP 的运行时类，用于 Module 级别初始化
- **UIAbility**：包含 UI 的应用组件，负责与用户交互
- **ExtensionAbility**：面向特定场景的扩展组件
- **WindowStage**：窗口管理对象，弱耦合 UIAbility 与窗口

### 4.2 项目目录结构

```
entry/src/main/
├── ets/
│   ├── entryability/          # UIAbility 组件
│   │   └── EntryAbility.ets   # 入口 Ability
│   ├── pages/                 # 页面目录
│   │   ├── Index.ets         # 首页
│   │   ├── Login.ets         # 登录页
│   │   └── User/
│   │       └── Profile.ets   # 用户资料页
│   ├── components/           # 自定义组件
│   │   ├── UserCard.ets
│   │   └── LoadingSpinner.ets
│   ├── services/             # 业务服务层
│   │   ├── UserService.ets
│   │   └── HttpClient.ets
│   ├── models/               # 数据模型
│   │   ├── UserInfo.ets
│   │   └── ApiResponse.ets
│   ├── utils/                # 工具函数
│   │   ├── DateUtil.ets
│   │   └── StorageUtil.ets
│   ├── constants/            # 常量定义
│   │   └── AppConstants.ets
│   └── entrybackupability/   # 备份恢复 Ability
├── resources/                # 资源文件
│   ├── base/
│   │   ├── element/         # 值资源（字符串、颜色等）
│   │   ├── media/           # 图片、音频等
│   │   ├── profile/         # 配置文件
│   │   └── layout/          # 布局文件
│   ├── rawfile/             # 原始文件
│   └── zh_CN/               # 中文资源
└── module.json5             # 模块配置
```

### 4.3 UIAbility 生命周期规范

UIAbility 生命周期状态：Create → Foreground → Background → Destroy

```typescript
import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  
  // 1. Create 状态 - Ability 创建时触发
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info('EntryAbility onCreate');
    // 执行页面初始化操作：变量定义、资源加载
  }
  
  // 2. WindowStageCreate - 窗口创建时触发
  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('EntryAbility onWindowStageCreate');
    
    // 设置主窗口加载的页面
    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        console.error(`Failed to load content: ${JSON.stringify(err)}`);
        return;
      }
      console.info('Succeeded in loading content');
    });
    
    // 订阅窗口事件
    windowStage.on('windowStageEvent', (event) => {
      console.info(`WindowStage event: ${event}`);
    });
  }
  
  // 3. Foreground 状态 - 进入前台时触发
  onForeground(): void {
    console.info('EntryAbility onForeground');
    // 申请资源、恢复状态
  }
  
  // 4. Background 状态 - 进入后台时触发
  onBackground(): void {
    console.info('EntryAbility onBackground');
    // 释放资源、保存状态
  }
  
  // 5. WindowStageDestroy - 窗口销毁时触发
  onWindowStageDestroy(): void {
    console.info('EntryAbility onWindowStageDestroy');
    // 释放窗口相关资源
  }
  
  // 6. Destroy 状态 - Ability 销毁时触发
  onDestroy(): void {
    console.info('EntryAbility onDestroy');
    // 释放所有资源
  }
}
```

**生命周期最佳实践：**
1. **onCreate/onDestroy**：执行一次性的初始化和销毁操作
2. **onForeground/onBackground**：管理资源申请和释放，避免内存泄漏
3. **生命周期回调中只执行轻量级操作**，耗时任务使用异步处理
4. 状态持久化在 `onBackground`，状态恢复在 `onForeground`

### 4.4 module.json5 配置规范

```json
{
  "module": {
    "name": "entry",
    "type": "entry",
    "description": "$string:module_desc",
    "mainElement": "EntryAbility",
    "deviceTypes": [
      "phone",
      "tablet"
    ],
    "pages": "$profile:main_pages",
    "abilities": [
      {
        "name": "EntryAbility",
        "srcEntry": "./ets/entryability/EntryAbility.ets",
        "description": "$string:EntryAbility_desc",
        "icon": "$media:layered_image",
        "label": "$string:EntryAbility_label",
        "startWindowIcon": "$media:startIcon",
        "startWindowBackground": "$color:start_window_background",
        "exported": true,
        "launchType": "singleton"
      }
    ],
    "extensionAbilities": [
      {
        "name": "EntryBackupAbility",
        "srcEntry": "./ets/entrybackupability/EntryBackupAbility.ets",
        "type": "backup"
      }
    ],
    "requestPermissions": [
      {
        "name": "ohos.permission.INTERNET"
      },
      {
        "name": "ohos.permission.GET_NETWORK_INFO"
      }
    ]
  }
}
```

### 4.5 Ability 启动模式

| 启动模式 | 说明 | 适用场景 |
|---------|------|---------|
| singleton | 单实例模式，系统中只存在一个实例 | 首页、主界面 |
| multiton | 多实例模式，每次启动创建新实例 | 详情页、独立任务 |
| specified | 指定实例模式，由开发者决定复用或新建 | 特殊业务场景 |

```json
{
  "abilities": [
    {
      "name": "EntryAbility",
      "launchType": "singleton"
    },
    {
      "name": "DetailAbility", 
      "launchType": "multiton"
    }
  ]
}
```

---

## 5. 状态管理规范

### 5.1 状态管理装饰器总览

| 装饰器 | 作用域 | 同步方向 | 初始化 | 使用场景 |
|--------|--------|---------|--------|---------|
| `@State` | 组件内 | 本地状态 | 必须本地初始化 | 组件内部状态 |
| `@Prop` | 父子组件 | 父→子单向 | 父组件传递 | 父传子只读数据 |
| `@Link` | 父子组件 | 双向同步 | 父组件传递($) | 父子双向绑定 |
| `@Provide`/`@Consume` | 跨层级 | 双向同步 | @Provide可初始化 | 跨组件层级共享 |
| `@ObjectLink` | 组件内 | 双向同步 | 父组件传递 | 嵌套对象属性观察 |
| `@StorageLink` | 应用全局 | 双向同步 | 必须初始化 | 应用级持久化状态 |
| `@StorageProp` | 应用全局 | 单向读取 | 必须初始化 | 读取应用级状态 |
| `@Watch` | 监听变化 | - | - | 监听状态变化回调 |

### 5.2 @State 使用规范

```typescript
@Component
struct Counter {
  // ✅ 正确：必须本地初始化
  @State private count: number = 0;
  @State private message: string = 'Hello';
  @State private userList: UserInfo[] = [];
  @State private isLoading: boolean = false;
  
  // ❌ 错误：未初始化
  // @State private value: number;
  
  build() {
    Column() {
      Text(`Count: ${this.count}`)
      Button('Add')
        .onClick(() => {
          this.count++;  // ✅ 状态变化触发 UI 刷新
        })
    }
  }
}
```

**@State 约束：**
- 必须本地初始化
- 支持类型：Object、class、string、number、boolean、enum 及其数组
- 不支持 any、undefined、null
- 嵌套对象的属性变化无法触发更新（需配合 @Observed）

### 5.3 @Prop 使用规范

```typescript
// 父组件
@Entry
@Component
struct Parent {
  @State private parentCount: number = 10;
  
  build() {
    Column() {
      Text(`Parent: ${this.parentCount}`)
      // ✅ 正确：单向传递，子组件可读取但修改不影响父组件
      ChildComponent({ count: this.parentCount })
      
      Button('Update Parent')
        .onClick(() => {
          this.parentCount++;
        })
    }
  }
}

// 子组件
@Component
struct ChildComponent {
  @Prop count: number;  // ✅ 不可本地初始化，必须由父组件传递
  
  build() {
    Column() {
      Text(`Child: ${this.count}`)
      Button('Try Update')
        .onClick(() => {
          // ✅ 可以修改本地副本，但不会同步到父组件
          this.count++;
        })
    }
  }
}
```

### 5.4 @Link 使用规范

```typescript
// 父组件
@Entry
@Component
struct Parent {
  @State private parentCount: number = 10;
  @State private inputText: string = '';
  
  build() {
    Column() {
      Text(`Parent: ${this.parentCount}`)
      
      // ✅ 正确：使用 $ 传递引用，实现双向绑定
      ChildComponent({ count: $parentCount, text: $inputText })
    }
  }
}

// 子组件
@Component
struct ChildComponent {
  @Link count: number;  // ✅ 双向绑定
  @Link text: string;
  
  build() {
    Column() {
      Text(`Child: ${this.count}`)
      Button('Update')
        .onClick(() => {
          // ✅ 修改会同步到父组件
          this.count++;
        })
      
      TextInput({ text: this.text })
        .onChange((value) => {
          // ✅ 输入变化同步到父组件
          this.text = value;
        })
    }
  }
}
```

### 5.5 @Provide/@Consume 使用规范

```typescript
// 定义状态类型
interface AppState {
  theme: 'light' | 'dark';
  userInfo: UserInfo | null;
  isLoggedIn: boolean;
}

// 祖先组件
@Entry
@Component
struct App {
  // ✅ 使用 @Provide 提供全局状态
  @Provide('appTheme') theme: 'light' | 'dark' = 'light';
  @Provide('userInfo') userInfo: UserInfo | null = null;
  @Provide('isLoggedIn') isLoggedIn: boolean = false;
  
  build() {
    Column() {
      Header()
      Content()
      Footer()
    }
  }
}

// 深层子组件 - 无需逐层传递
@Component
struct Content {
  // ✅ 使用 @Consume 消费状态
  @Consume('appTheme') theme: 'light' | 'dark';
  @Consume('userInfo') userInfo: UserInfo | null;
  
  build() {
    Column() {
      Text(`Current Theme: ${this.theme}`)
        .fontColor(this.theme === 'light' ? '#000' : '#FFF')
      
      if (this.userInfo) {
        Text(`Welcome, ${this.userInfo.name}`)
      }
    }
    .backgroundColor(this.theme === 'light' ? '#FFF' : '#000')
  }
}
```

### 5.6 @Observed/@ObjectLink 嵌套对象观察

```typescript
// ✅ 使用 @Observed 标记需要观察的类
@Observed
class Person {
  name: string;
  age: number;
  address: Address;
  
  constructor(name: string, age: number, address: Address) {
    this.name = name;
    this.age = age;
    this.address = address;
  }
}

@Observed
class Address {
  city: string;
  street: string;
  
  constructor(city: string, street: string) {
    this.city = city;
    this.street = street;
  }
}

// 父组件
@Entry
@Component
struct Parent {
  @State private person: Person = new Person(
    '张三', 
    25, 
    new Address('北京', '朝阳区')
  );
  
  build() {
    Column() {
      // ✅ 传递对象引用
      PersonView({ person: this.person })
      AddressView({ address: this.person.address })
      
      Button('Update Age')
        .onClick(() => {
          this.person.age++;  // 会触发 UI 刷新
        })
    }
  }
}

// 子组件 - 观察 Person 对象
@Component
struct PersonView {
  @ObjectLink person: Person;  // ✅ 使用 @ObjectLink
  
  build() {
    Column() {
      Text(`Name: ${this.person.name}`)
      Text(`Age: ${this.person.age}`)
    }
  }
}

// 子组件 - 观察 Address 对象
@Component
struct AddressView {
  @ObjectLink address: Address;  // ✅ 使用 @ObjectLink
  
  build() {
    Column() {
      Text(`City: ${this.address.city}`)
      Text(`Street: ${this.address.street}`)
    }
  }
}
```

### 5.7 @StorageLink/@StorageProp 全局状态

```typescript
@Entry
@Component
struct GlobalStatePage {
  // ✅ 应用级全局状态，持久化存储
  @StorageLink('userToken') userToken: string = '';
  @StorageLink('isFirstLaunch') isFirstLaunch: boolean = true;
  
  // ✅ 只读全局状态
  @StorageProp('appVersion') appVersion: string = '1.0.0';
  
  build() {
    Column() {
      Text(`Version: ${this.appVersion}`)
      
      if (this.isFirstLaunch) {
        Text('Welcome! First time using app.')
        Button('Get Started')
          .onClick(() => {
            this.isFirstLaunch = false;  // 更新全局状态
          })
      }
    }
  }
}
```

### 5.8 状态管理最佳实践

**1. 选择合适的状态管理方案：**
```typescript
// 父子层级较近时 - 使用 @State + @Prop/@Link
// 跨多层组件时 - 使用 @Provide + @Consume
// 应用全局状态时 - 使用 @StorageLink/@StorageProp
// 复杂对象嵌套时 - 使用 @Observed + @ObjectLink
```

**2. 避免状态层层传递：**
```typescript
// ❌ 不推荐：层层传递，中间组件未使用但参与传递
// Parent -> Middle1 -> Middle2 -> Child

// ✅ 推荐：使用 @Provide/@Consume 跨层级共享
// Parent @Provide -> Child @Consume (跳过中间层)
```

**3. 精准控制状态变量关联组件数量：**
```typescript
// ❌ 不推荐：大对象的所有属性关联大量组件
@Observed
class BigData {
  prop1: string;
  prop2: number;
  prop3: boolean;
  // ... 更多属性
}

// ✅ 推荐：拆分为小对象，按需关联
@Observed
class UserInfo {
  name: string;
  avatar: string;
}

@Observed
class AppConfig {
  theme: string;
  fontSize: number;
}
```

**4. 减少不必要的深拷贝：**
```typescript
// ❌ 不推荐：@Prop 会深拷贝，如果子组件不修改值
@Component
struct Child {
  @Prop data: BigObject;  // 深拷贝开销大
}

// ✅ 推荐：使用 @ObjectLink
@Component
struct Child {
  @ObjectLink data: BigObject;  // 引用传递，无深拷贝
}
```

**5. 条件渲染优化：**
```typescript
// ❌ 不推荐：频繁切换导致父组件刷新
@Entry
@Component
struct Page {
  @State isShow: boolean = false;
  @State complexData: ComplexType = ...;
  
  build() {
    Column() {
      HeavyComponent()  // 不必要的刷新
      if (this.isShow) {
        Popup()
      }
    }
  }
}

// ✅ 推荐：使用 Stack 包裹条件渲染组件
@Entry
@Component
struct Page {
  @State isShow: boolean = false;
  @State complexData: ComplexType = ...;
  
  build() {
    Stack() {
      HeavyComponent()
      if (this.isShow) {
        Popup()
      }
    }
  }
}
```

---

## 6. UI 开发规范

### 6.1 组件定义规范

```typescript
// ✅ 正确的组件结构
@Component
struct UserProfileCard {
  // 1. 状态变量（@State, @Prop, @Link 等）
  @State private isExpanded: boolean = false;
  @Prop userName: string;
  @Link userData: UserInfo;
  
  // 2. 常量定义
  private readonly MAX_NAME_LENGTH: number = 50;
  private readonly DEFAULT_AVATAR: Resource = $r('app.media.default_avatar');
  
  // 3. 生命周期回调
  aboutToAppear() {
    this.initializeData();
  }
  
  aboutToDisappear() {
    this.cleanup();
  }
  
  // 4. 私有方法
  private initializeData(): void {
    // 初始化逻辑
  }
  
  private cleanup(): void {
    // 清理逻辑
  }
  
  private handleExpand(): void {
    this.isExpanded = !this.isExpanded;
  }
  
  // 5. build 方法
  build() {
    Column() {
      this.HeaderBuilder()
      if (this.isExpanded) {
        this.DetailBuilder()
      }
    }
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .shadow({ radius: 10, color: '#1F000000' })
  }
  
  // 6. @Builder 构建函数
  @Builder
  HeaderBuilder() {
    Row() {
      Image(this.DEFAULT_AVATAR)
        .width(48)
        .height(48)
        .borderRadius(24)
      
      Text(this.userName)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .onClick(() => this.handleExpand())
  }
  
  @Builder
  DetailBuilder() {
    Column() {
      Text(`Email: ${this.userData.email}`)
      Text(`Phone: ${this.userData.phone}`)
    }
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 12 })
  }
}
```

### 6.2 布局规范

**首选布局方案优先级：**
1. **Row/Column** - 简单线性布局
2. **Flex** - 弹性布局
3. **Stack** - 层叠布局
4. **Grid** - 网格布局
5. **List** - 列表布局（配合 LazyForEach）
6. **RelativeContainer** - 相对定位布局
7. **Absolute positioning** - 绝对定位（最后考虑）

```typescript
// ✅ 使用 Column + Row 构建标准页面结构
@Entry
@Component
struct StandardPage {
  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button() { Image($r('app.media.back')) }
        Text('页面标题')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Blank()  // 占位
        Button() { Image($r('app.media.more')) }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      
      // 内容区域
      Stack() {
        // 主内容
        Scroll() {
          Column({ space: 16 }) {
            // 内容组件
          }
          .padding(16)
        }
        .scrollable(ScrollDirection.Vertical)
        
        // 悬浮按钮
        FloatingButton()
          .position({ x: '80%', y: '85%' })
      }
      .layoutWeight(1)  // 占据剩余空间
      
      // 底部导航
      Row() {
        BottomNavItem('首页', $r('app.media.home'))
        BottomNavItem('分类', $r('app.media.category'))
        BottomNavItem('购物车', $r('app.media.cart'))
        BottomNavItem('我的', $r('app.media.profile'))
      }
      .width('100%')
      .height(64)
      .justifyContent(FlexAlign.SpaceAround)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
```

### 6.3 列表渲染规范

```typescript
// ✅ 使用 LazyForEach 实现长列表虚拟滚动
import { LazyForEach } from '@kit.ArkUI';

// 数据源类
class DataSource implements IDataSource {
  private dataArray: string[] = [];
  
  constructor(data: string[]) {
    this.dataArray = data;
  }
  
  totalCount(): number {
    return this.dataArray.length;
  }
  
  getData(index: number): string {
    return this.dataArray[index];
  }
  
  registerDataChangeListener(listener: DataChangeListener): void {}
  unregisterDataChangeListener(listener: DataChangeListener): void {}
}

@Entry
@Component
struct ListPage {
  private dataSource: DataSource = new DataSource(
    Array.from({ length: 1000 }, (_, i) => `Item ${i}`)
  );
  
  build() {
    List() {
      LazyForEach(this.dataSource, (item: string, index: number) => {
        ListItem() {
          Row() {
            Text(item)
              .fontSize(16)
            Blank()
            Image($r('app.media.arrow_right'))
          }
          .padding(16)
          .width('100%')
        }
      }, (item: string, index: number) => index.toString())
    }
    .width('100%')
    .height('100%')
    .divider({ strokeWidth: 1, color: '#E5E5E5' })
    .cachedCount(5)  // 预加载数量
    .edgeEffect(EdgeEffect.Spring)
  }
}
```

### 6.4 样式规范

**资源引用优先：**
```typescript
// ✅ 使用资源文件管理样式
{
  "color": {
    "primary": "#007DFF",
    "text_primary": "#333333",
    "text_secondary": "#666666",
    "background": "#F5F5F5",
    "divider": "#E5E5E5"
  }
}

// 代码中使用
Text('Title')
  .fontColor($r('app.color.text_primary'))
  .backgroundColor($r('app.color.background'))
```

**组件封装：**
```typescript
// ✅ 创建可复用的样式组件
@Component
export struct PrimaryButton {
  @Prop text: string;
  @Prop onClick: () => void;
  @Prop enabled: boolean = true;
  
  build() {
    Button(this.text)
      .fontSize(16)
      .fontColor('#FFFFFF')
      .backgroundColor(this.enabled ? '#007DFF' : '#CCCCCC')
      .width('100%')
      .height(48)
      .borderRadius(8)
      .enabled(this.enabled)
      .onClick(() => {
        if (this.enabled) {
          this.onClick();
        }
      })
  }
}

// 使用
PrimaryButton({
  text: '提交',
  onClick: () => this.handleSubmit(),
  enabled: this.isFormValid
})
```

---

## 7. 性能优化规范

### 7.1 渲染性能优化

**1. 使用 LazyForEach 替代 ForEach：**
```typescript
// ❌ 不推荐：ForEach 会一次性渲染所有项
ForEach(this.dataList, (item: Item) => {
  ListItem() { /* ... */ }
})

// ✅ 推荐：LazyForEach 只渲染可见项
LazyForEach(this.dataSource, (item: Item, index: number) => {
  ListItem() { /* ... */ }
}, (item: Item) => item.id)
```

**2. 条件渲染优化：**
```typescript
// ❌ 不推荐：频繁切换导致父组件刷新
@State isShow: boolean = false;

build() {
  Column() {
    HeavyComponent()  // 不必要的刷新
    if (this.isShow) {
      Popup()
    }
  }
}

// ✅ 推荐：使用 Stack 隔离
build() {
  Stack() {
    HeavyComponent()
    if (this.isShow) {
      Popup()
    }
  }
}
```

**3. 避免不必要的状态变量：**
```typescript
// ❌ 不推荐：普通变量标记为状态
@State private computedValue: number = 0;

aboutToAppear() {
  this.computedValue = this.a + this.b;  // 计算后不再变化
}

// ✅ 推荐：使用普通变量
private computedValue: number = 0;

aboutToAppear() {
  this.computedValue = this.a + this.b;
}
```

### 7.2 内存优化

**1. 及时释放资源：**
```typescript
@Component
struct MediaPlayer {
  private player: AVPlayer | null = null;
  
  aboutToAppear() {
    this.player = new AVPlayer();
  }
  
  aboutToDisappear() {
    // ✅ 及时释放资源
    if (this.player) {
      this.player.release();
      this.player = null;
    }
  }
}
```

**2. 图片资源优化：**
```typescript
// ✅ 使用适当尺寸的图片
Image($r('app.media.banner'))
  .width('100%')
  .height(200)
  .objectFit(ImageFit.Cover)
  .alt($r('app.media.placeholder'))  // 占位图
```

**3. 大对象使用 ArrayBuffer：**
```typescript
// ❌ 不推荐：普通数组存储大量数据
let largeArray: number[] = new Array(1000000);

// ✅ 推荐：使用 ArrayBuffer
let buffer: ArrayBuffer = new ArrayBuffer(1000000);
let view: DataView = new DataView(buffer);
```

### 7.3 启动性能优化

**1. 异步加载数据：**
```typescript
@Entry
@Component
struct SplashPage {
  @State isReady: boolean = false;
  
  aboutToAppear() {
    // ✅ 异步初始化，不阻塞 UI
    this.initializeAsync();
  }
  
  private async initializeAsync(): Promise<void> {
    await Promise.all([
      this.loadUserData(),
      this.loadConfiguration(),
      this.preloadResources()
    ]);
    this.isReady = true;
  }
  
  build() {
    if (!this.isReady) {
      LoadingView()
    } else {
      MainContent()
    }
  }
}
```

**2. 路由懒加载：**
```typescript
// ✅ 使用动态导入实现路由懒加载
@Entry
@Component
struct RouterPage {
  @Builder
  pageBuilder(name: string) {
    if (name === 'detail') {
      // 动态加载 Detail 页面
      import('./DetailPage').then((module) => {
        module.DetailPage()
      })
    }
  }
}
```

### 7.4 函数调用优化

```typescript
// ❌ 不推荐：参数声明与实际使用不一致
function calculate(a: number, b: number): number {
  // 错误：实际传入了3个参数
  return this.add(a, b, 0);
}

// ✅ 推荐：参数声明与实际一致
function calculate(a: number, b: number, c: number = 0): number {
  return this.add(a, b, c);
}

// ❌ 不推荐：循环中重复读取状态变量
build() {
  Column() {
    for (let i = 0; i < this.items.length; i++) {
      Text(`${this.items[i].name}: ${this.status}`)  // 重复读取 status
    }
  }
}

// ✅ 推荐：提前读取状态变量
build() {
  let currentStatus = this.status;  // 提前读取
  Column() {
    for (let i = 0; i < this.items.length; i++) {
      Text(`${this.items[i].name}: ${currentStatus}`)
    }
  }
}
```

---

## 8. 安全开发规范

### 8.1 数据安全

**1. 敏感数据加密存储：**
```typescript
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

class SecureStorage {
  // ✅ 敏感数据加密后存储
  static async saveSecureData(key: string, data: string): Promise<void> {
    const encryptResult = await this.encryptData(data);
    await localStorage.set(key, encryptResult);
  }
  
  private static async encryptData(data: string): Promise<Uint8Array> {
    const key = await cryptoFramework.createSymKey('AES256');
    const cipher = cryptoFramework.createCipher('AES256|CBC|PKCS7');
    // 加密逻辑
    return new Uint8Array();
  }
}
```

**2. 安全的数据传输：**
```typescript
import { http } from '@kit.NetworkKit';

class HttpClient {
  private static readonly BASE_URL: string = 'https://api.example.com';
  
  static async request<T>(
    method: http.RequestMethod,
    path: string,
    data?: object
  ): Promise<T> {
    const options: http.HttpRequestOptions = {
      method,
      url: `${this.BASE_URL}${path}`,
      header: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${await this.getToken()}`
      },
      // ✅ 使用 HTTPS
      usingProtocol: http.HttpProtocol.HTTPS
    };
    
    if (data) {
      options.extraData = JSON.stringify(data);
    }
    
    const response = await http.createHttp().request(options);
    return JSON.parse(response.result as string) as T;
  }
}
```

### 8.2 权限管理

**1. 最小权限原则：**
```json
// module.json5
{
  "module": {
    "requestPermissions": [
      {
        "name": "ohos.permission.INTERNET",
        "reason": "$string:internet_permission_reason"
      },
      {
        "name": "ohos.permission.CAMERA",
        "reason": "$string:camera_permission_reason",
        "usedScene": {
          "abilities": ["EntryAbility"],
          "when": "inuse"
        }
      }
    ]
  }
}
```

**2. 动态权限申请：**
```typescript
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';

class PermissionManager {
  static async requestPermission(permission: Permissions): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const authResults = await atManager.requestPermissionsFromUser(
      getContext(),
      [permission]
    );
    return authResults.authResults[0] === 0;
  }
  
  static async checkPermission(permission: Permissions): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const grantStatus = await atManager.checkAccessToken(
      getContext().applicationInfo.accessTokenId,
      permission
    );
    return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  }
}
```

### 8.3 代码安全

**1. 输入验证：**
```typescript
class Validator {
  // ✅ 验证用户输入
  static validateEmail(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }
  
  static validatePhone(phone: string): boolean {
    const phoneRegex = /^1[3-9]\d{9}$/;
    return phoneRegex.test(phone);
  }
  
  static sanitizeInput(input: string): string {
    // 移除潜在危险的字符
    return input.replace(/[<>"']/g, '');
  }
}
```

**2. 防止逆向工程：**
```typescript
// ✅ 代码混淆配置 build-profile.json5
{
  "buildOption": {
    "arkOptions": {
      "obfuscation": {
        "ruleOptions": {
          "enable": true,
          "files": ["./obfuscation-rules.txt"]
        },
        "consumerRules": ["./consumer-rules.txt"]
      }
    }
  }
}
```

---

## 9. 最佳实践总结

### 9.1 代码组织原则

1. **单一职责**：每个组件/类只负责一个功能
2. **开闭原则**：对扩展开放，对修改关闭
3. **依赖倒置**：依赖抽象而非具体实现
4. **DRY 原则**：不要重复自己，提取公共逻辑

### 9.2 开发流程规范

1. **编码前**：
   - 阅读需求文档
   - 设计组件结构
   - 定义数据接口

2. **编码中**：
   - 遵循命名规范
   - 编写单元测试
   - 添加必要注释

3. **编码后**：
   - 代码审查
   - 性能测试
   - 安全扫描

### 9.3 常见反模式避免

```typescript
// ❌ 反模式 1：在 build 中执行副作用
build() {
  this.fetchData();  // 错误！build 应该纯函数
  return Column() { }
}

// ✅ 正确做法
aboutToAppear() {
  this.fetchData();  // 在生命周期中调用
}

// ❌ 反模式 2：直接修改 @Prop 期望同步父组件
@Component
struct Child {
  @Prop value: number;
  
  handleClick() {
    this.value++;  // 不会同步到父组件
  }
}

// ✅ 正确做法：使用 @Link
@Component
struct Child {
  @Link value: number;
  
  handleClick() {
    this.value++;  // 双向同步
  }
}

// ❌ 反模式 3：嵌套过深的组件树
build() {
  Column() {
    Row() {
      Column() {
        Row() {
          Column() {
            // 太深了！
          }
        }
      }
    }
  }
}

// ✅ 正确做法：提取为独立组件
build() {
  Column() {
    HeaderComponent()
    ContentComponent()
    FooterComponent()
  }
}

// ❌ 反模式 4：在循环中使用复杂表达式
build() {
  Column() {
    ForEach(this.items, (item) => {
      Text(this.getFormattedName(item.firstName, item.lastName))
    })
  }
}

// ✅ 正确做法：预处理数据
aboutToAppear() {
  this.processedItems = this.items.map(item => ({
    ...item,
    displayName: this.getFormattedName(item.firstName, item.lastName)
  }));
}
```

### 9.4 调试与日志规范

```typescript
import { hilog } from '@kit.PerformanceAnalysisKit';

class Logger {
  private static readonly DOMAIN: number = 0x0001;
  private static readonly TAG: string = 'MyApp';
  
  static debug(message: string): void {
    hilog.debug(this.DOMAIN, this.TAG, message);
  }
  
  static info(message: string): void {
    hilog.info(this.DOMAIN, this.TAG, message);
  }
  
  static warn(message: string): void {
    hilog.warn(this.DOMAIN, this.TAG, message);
  }
  
  static error(message: string, error?: Error): void {
    hilog.error(this.DOMAIN, this.TAG, 
      `${message}${error ? ` - ${error.message}` : ''}`);
  }
}

// 使用
Logger.info('User logged in successfully');
Logger.error('Failed to load data', error);
```

---

## 附录

### A. 参考文档

- [HarmonyOS NEXT 开发文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/application-dev-guide-V5)
- [ArkTS 编程规范](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-v5/arkts-coding-style-guide-V5)
- [状态管理最佳实践](https://developer.huawei.com/consumer/cn/doc/best-practices-V5/bpta-status-management-V5)
- [ArkTS 高性能编程](https://developer.huawei.com/consumer/cn/doc/best-practices-V5/bpta-arkts-high-performance-V5)
- [从 TypeScript 到 ArkTS 迁移指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/typescript-to-arkts-migration-guide-V5)

### B. 常用工具

- **DevEco Studio**：官方 IDE，支持代码检查、调试、性能分析
- **Code Linter**：ArkTS 代码规范检查工具
- **HiProfiler**：性能分析工具
- **模拟器**：本地和远程设备模拟

### C. 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-03-07 | 初始版本，基于 HarmonyOS NEXT API 12+ |

---

*本文档持续更新，建议定期查阅最新版本。*
