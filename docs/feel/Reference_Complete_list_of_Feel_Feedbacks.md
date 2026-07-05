# Feel 插件反馈完整列表

## 概述

Feel 插件提供了多种类型的反馈效果。有些反馈专注于或与 GameObject 交互，有些与相机（或其部分）交互，有些与第三方系统交互，还有一些不适合任何特定类别。请注意，其中一些是自主的，而另一些需要场景中存在另一个对象（通常称为 Shaker，因为它负责震动效果）。本列表解释了所有这些内容，如果您想了解更多信息，可以随时查看类本身，它们都有注释。

本页面仅列出所有反馈。如果您想了解每个反馈的所有详细信息，请查看 API 文档。

---

## 📋 目录

- [Feel 插件反馈完整列表](#feel-插件反馈完整列表)
  - [概述](#概述)
  - [📋 目录](#-目录)
  - [动画 (Animation)](#动画-animation)
  - [音频 (Audio)](#音频-audio)
  - [相机 (Camera)](#相机-camera)
    - [相机设置说明](#相机设置说明)
  - [事件 (Events)](#事件-events)
  - [游戏对象 (GameObject)](#游戏对象-gameobject)
  - [反馈系统 (Feedbacks)](#反馈系统-feedbacks)
  - [HDRP 体积 (HDRP Volume)](#hdrp-体积-hdrp-volume)
  - [循环 (Loop)](#循环-loop)
  - [触觉反馈 (Nice Vibrations)](#触觉反馈-nice-vibrations)
  - [粒子系统 (Particles)](#粒子系统-particles)
  - [暂停 (Pause)](#暂停-pause)
  - [后期处理 (Post Processing)](#后期处理-post-processing)
  - [渲染器 (Renderer)](#渲染器-renderer)
  - [场景 (Scene)](#场景-scene)
  - [弹簧系统 (Springs)](#弹簧系统-springs)
  - [TextMesh Pro](#textmesh-pro)
  - [时间控制 (Time)](#时间控制-time)
  - [变换 (Transform)](#变换-transform)
    - [关于缩放的注意事项](#关于缩放的注意事项)
  - [用户界面 (UI)](#用户界面-ui)
  - [URP 体积 (URP Volume)](#urp-体积-urp-volume)
  - [其他 (Various)](#其他-various)
  - [调试 (Debug)](#调试-debug)
  - [🎯 使用提示](#-使用提示)
  - [🔗 相关资源](#-相关资源)

---

## 动画 (Animation)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Animation Parameter** | 在动画器上播放任何动画。将动画器绑定到反馈的检查器中，它将允许您更新触发器和/或布尔动画参数。 | Animator |
| **Animation Play State** | 通过名称播放状态，可以是固定时间或标准化时间，在 MMF_PlayerDemo 场景中有示例。 | Animator |
| **Animator Speed** | 在运行时调整目标动画器的速度。 | Animator |
| **Animator Cross Fade** | 让您的动画器交叉淡入到指定状态，可以是常规时间或标准化时间。 | Animator |
| **Animation Sprite Sheet** | 使用简单的精灵列表为目标 Sprite Renderers 和/或 Images 设置动画，无需 Animator 组件。 | Sprite Renderer 或 Image |

---

## 音频 (Audio)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **AudioSource** | 按需播放、暂停、取消暂停或停止预先存在的音频源。您还可以以随机音调和音量播放/暂停/停止/恢复它，并通过可选的音频混音器组。 | AudioSource |
| **Sound** | 另一种触发声音的方式。您指定一个音频剪辑，然后可以决定按需实例化、缓存、创建对象池或触发声音事件。此反馈还允许您从编辑器预览声音。 | MMSoundManager（事件模式） |
| **AudioSource Pitch** | 随时间调整 AudioSource 的音调。 | MMAudioSourcePitchShaker |
| **AudioSource Stereo Pan** | 随时间改变 AudioSource 的立体声平移值。 | MMAudioSourceStereoPanShaker |
| **AudioSource Volume** | 让您随时间补间音频源的音量。 | MMAudioSourceVolumeShaker |
| **Distortion Filter** | 随时间补间失真滤波器的失真级别。 | MMAudioSourceDistortionShaker + Distortion Filter |
| **Echo Filter** | 随时间补间回声效果。 | MMAudioSourceEchoShaker + Echo Filter |
| **High Pass Filter** | 随时间补间高通滤波器的截止频率。 | MMAudioSourceHighPassShaker + High Pass Filter |
| **Low Pass Filter** | 随时间补间低通滤波器的截止频率。 | MMAudioSourceLowPassShaker + Low Pass Filter |
| **Reverb Filter** | 随时间补间混响级别。 | MMAudioSourceReverbShaker + Reverb Filter |
| **AudioMixer Snapshot Transition** | 让您在指定持续时间内过渡到目标快照。 | Audio Mixer |
| **MMPlaylist** | 让您从反馈远程控制（播放/暂停/停止/上一个/下一个等）MMPlaylist。 | MMPlaylist |
| **MMSoundManager All Sounds Control** | 控制 MMSoundManager 上播放的所有声音。 | MMSoundManager |
| **MMSoundManager Save and Load** | 保存和加载 MMSoundManager 设置（轨道音量等）。 | MMSoundManager |
| **MMSoundManager Sound** | 让您在 MMSoundManager 上播放声音。 | MMSoundManager |
| **MMSoundManager Sound Control** | 让您对 MMSoundManager 上播放的声音进行播放/暂停/恢复/设置音量等操作。 | MMSoundManager |
| **MMSoundManager Sound Fade** | 让您在 MMSoundManager 上淡入/淡出声音。 | MMSoundManager |
| **MMSoundManager Track Control** | 让您控制 MMSoundManager 上的整个轨道（音乐、UI、音效、主轨道）。 | MMSoundManager |
| **MMSoundManager Track Fade** | 让您淡入淡出 MMSoundManager 的轨道。 | MMSoundManager |

---

## 相机 (Camera)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Camera Shake** | 简单地随时间震动相机，让您指定持续时间（秒）、振幅和频率。 | MMCameraShaker |
| **Camera Zoom** | 在反馈播放时放大或缩小，可以是指定持续时间或直到进一步通知。 | MMCameraZoom 或 MMCinemachineZoom |
| **Flash** | 在屏幕上闪烁图像或颜色，持续时间很短。 | MMFlash |
| **Fade** | 淡入或淡出图像，适用于过渡效果。 | MMFader |
| **Field of View** | 随时间控制相机的视野。 | MMCameraFieldOfViewShaker 或 MMCinemachineFieldOfViewShaker |
| **Clipping Planes** | 让您随时间补间相机的近裁剪平面和远裁剪平面距离。 | MMCameraClippingPlanesShaker 或 MMCinemachineClippingPlanesShaker |
| **Orthographic Size** | 仅适用于正交/2D 相机，让您随时间补间相机的大小，基本上是放大或缩小。 | MMCameraOrthographicSizeShaker 或 MMCinemachineOrthographicSizeShaker |
| **Cinemachine Transition** | 让您过渡到另一个虚拟相机，使用您选择的混合方式，并自动管理其他相机的优先级。 | MMCinemachinePriorityListener |
| **Cinemachine Impulse** | 触发 Cinemachine Impulse 来震动您的虚拟相机。 | Cinemachine Impulse Listener |
| **Cinemachine Impulse Source** | 让您在目标 Cinemachine Impulse 源上生成脉冲。 | Cinemachine Impulse Source |
| **Cinemachine Impulse Clear** | 取消任何可能正在播放的 Cinemachine Impulse。 | - |

### 相机设置说明

**相机抖动设置：**
- 对于常规相机：使用 MMCameraShaker
- 对于 Cinemachine：使用 MMCinemachineCameraShaker 并在虚拟相机上设置噪声配置

**相机层级结构建议：**
```
MyCharacter (主对象，缩放 1,1,1)
└── MyModelContainer (可选容器，缩放 1,1,1)
    └── MySquashAndStretchContainer (空对象，缩放 1,1,1)
        └── MyActualModel (您的网格渲染器，缩放可以是任何值)
```

---

## 事件 (Events)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Unity Events** | 让您将任何类型的 Unity 事件与反馈关联，并在播放、停止、初始化或重置时触发它们。 | - |
| **MMGameEvent** | 在播放时触发指定名称的 MMGameEvent。 | - |

---

## 游戏对象 (GameObject)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Destroy** | 让您销毁、立即销毁或禁用特定的游戏对象。 | - |
| **Enable Behaviour** | 在反馈播放、初始化、停止或重置时启用或禁用 MonoBehaviour。 | - |
| **Float Controller** | 可能是所有反馈中最强大的一个，它让您控制任何 MonoBehaviour 上的浮点值。 | FloatController |
| **Instantiate Object** | 在反馈播放时在指定位置生成对象。 | - |
| **Rigidbody** | 向 Rigidbody 添加力或扭矩。 | Rigidbody |
| **Rigidbody2D** | 向 Rigidbody2D 添加力或扭矩。 | Rigidbody2D |
| **Collider** | 启用/禁用/切换目标碰撞器，或更改其触发器状态。 | Collider |
| **Collider2D** | 启用/禁用/切换目标 2D 碰撞器，或更改其触发器状态。 | Collider2D |
| **Property** | 让您定位和控制任何对象（包括 ScriptableObjects）上的任何属性或字段（浮点数、向量、整数、字符串、颜色等），并随时间控制它。 | - |
| **Set Active** | 设置对象为活动或非活动状态。 | - |
| **MMRadioSignal** | 此反馈让您控制 MMRadioSignal，然后可以广播它以控制接收器，以控制任何组件上的任何值。 | MMRadioSignal |
| **MMRadio Broadcast** | 类似于 MMRadioSignal，但直接向任何接收器广播信号，而不是通过发射器。 | - |

---

## 反馈系统 (Feedbacks)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Feedbacks Player** | 让您在指定范围内触发其他 MMF_Players，或者让您指定目标 MMF_Player，在这种情况下，此反馈将匹配其目标的总持续时间。 | MMF_Player |
| **MMF Player Chain** | 让您将多个 MMF Players 按顺序排列，一个接一个地播放它们，带有可选的延迟。 | MMF_Player |
| **Player Control** | 让您在一个或多个目标 MMF Players 上触发方法。 | MMF_Player |

---

## HDRP 体积 (HDRP Volume)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Bloom HDRP** | 随时间控制泛光强度。 | HDRP Volume |
| **Chromatic Aberration HDRP** | 随时间控制色差效果的强度。 | HDRP Volume |
| **Channel Mixer HDRP** | 随时间独立控制红色、绿色和蓝色通道。 | HDRP Volume |
| **Color Adjustments HDRP** | 让您使用许多颜色调整选项：后期曝光、饱和度、色调偏移、对比度等。 | HDRP Volume |
| **Depth of Field HDRP** | 随时间控制 HDRP 景深焦点距离或近/远范围。 | HDRP Volume |
| **Film Grain HDRP** | 让您随时间控制颗粒强度。 | HDRP Volume |
| **Lens Distortion HDRP** | 按需进行镜头畸变。 | HDRP Volume |
| **Motion Blur HDRP** | 随时间控制运动模糊级别。 | HDRP Volume |
| **Panini Projection HDRP** | 随时间调整 panini 投影的距离和裁剪以适应。 | HDRP Volume |
| **Vignette HDRP** | 随时间控制晕影参数。 | HDRP Volume |
| **White Balance HDRP** | 随时间控制白平衡参数。 | HDRP Volume |

---

## 循环 (Loop)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Looper** | 将当前 MMF_Player 序列的"头"移回列表中上方的另一个反馈。然后您可以让该序列重复您选择的次数或无限次。 | MMF_Player |
| **Looper Start** | 可以作为暂停，也可以作为循环的起点。 | MMF_Player |

---

## 触觉反馈 (Nice Vibrations)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Nice Vibrations Preset** | 播放预设触觉，有限但超级简单的预定义触觉模式。 | - |
| **Nice Vibrations Emphasis** | 播放 Emphasis 触觉，短触觉爆发，其振幅和频率可以实时控制，在 CoreHaptics/iOS 中也称为 Transients。 | - |
| **Nice Vibrations Clip** | 使用此反馈播放 .haptic 剪辑，可选地随机化其级别和频率。 | - |
| **Nice Vibrations Continuous** | 让您在特定持续时间内以指定的振幅和频率播放连续触觉。此反馈还将让您随机化这些参数，并随时间调制它们。 | - |
| **Nice Vibrations Control** | 在全局级别与触觉交互，停止所有触觉、启用或禁用它们、调整其全局级别或初始化/释放触觉引擎。 | - |

---

## 粒子系统 (Particles)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Particles Instantiation** | 实例化粒子并播放它们。您可以按需实例化或缓存它们，并且可以指定您想要它们的位置。 | - |
| **Particles Play** | 控制（播放、暂停、停止、恢复）现有的粒子系统。反馈还允许您按需将其移动到反馈的位置。 | Particle System |
| **Visual Effect** | 让您控制目标视觉效果并播放/暂停/停止等。 | Visual Effect |
| **Visual Effect Set Property** | 让您在目标视觉效果上设置任何类型的属性 ID 的值。 | Visual Effect |

---

## 暂停 (Pause)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Pause** | 在遇到时导致反馈序列中的暂停，防止序列中较低的任何其他反馈运行，直到暂停完成。 | - |
| **Holding Pause** | 保持直到序列中的所有先前反馈以及此反馈的暂停都已执行。 | - |

---

## 后期处理 (Post Processing)

> **注意：** 所有这些都需要在 PostProcessing Volume 上有相应的 shaker 才能正常工作。

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Bloom** | 随时间控制泛光强度和阈值。 | MMBloomShaker |
| **Chromatic Aberration** | 随时间控制色差效果的强度。 | MMChromaticAberrationShaker |
| **Color Grading** | 让您使用许多颜色分级选项：后期曝光、饱和度、色调偏移、对比度等。 | MMColorGradingShaker |
| **Depth of Field** | 让您随时间控制景深焦点距离、光圈和焦距。 | MMDepthOfFieldShaker |
| **Global PP Volume Auto Blend** | 补间 PostProcessing 体积的权重。 | - |
| **Lens Distortion** | 按需进行镜头畸变。 | MMLensDistortionShaker |
| **PP Moving Filter** | 将后期处理滤镜移入或移出相机。 | - |
| **Vignette** | 随时间控制晕影参数。 | MMVignetteShaker |

---

## 渲染器 (Renderer)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Flicker** | 让您快速更改材质的颜色。默认情况下，这将控制目标渲染器的着色器的颜色值，但反馈也允许您指定自己的值。 | Renderer |
| **Fog** | 让您设置场景雾的密度、颜色、结束和开始距离的动画。 | - |
| **Material** | 每次播放时更改目标渲染器的材质，从材质数组中。您可以按顺序或随机交换它们。 | Renderer |
| **Line Renderer** | 让您随时间更新线渲染器的宽度和颜色。 | Line Renderer |
| **Material Set Property** | 在目标渲染器的材质上设置您选择的属性的值。 | Renderer |
| **MMBlink** | 控制 MMBlink，让您进行高级闪烁行为，通过启用/禁用游戏对象、更改其 alpha、发射强度或着色器上的您选择的值），带或不带插值，并让您定义重复模式和阶段。 | MMBlink |
| **Shader Controller** | 类似于 Float Controller，让您控制任何着色器的大多数设置。 | ShaderController |
| **Shader Global** | 让您在运行时控制全局着色器属性。 | - |
| **Sprite** | 更改目标精灵渲染器上的精灵。 | Sprite Renderer |
| **SpriteRenderer** | 控制 SpriteRenderer 的颜色和 X 或 Y 翻转。 | Sprite Renderer |
| **SpriteRenderer Alpha** | 让您随时间设置目标精灵渲染器的 alpha 动画，无论其颜色如何。 | Sprite Renderer |
| **Skybox** | 让您分配新材质（随机或不随机）以将场景的天空盒更改为新材质。 | - |
| **TextureOffset** | 让您随时间控制目标渲染器材质的纹理偏移。 | Renderer |
| **TextureScale** | 让您随时间控制目标渲染器材质的纹理缩放。 | Renderer |
| **Trail Renderer** | 让您随时间更新轨迹渲染器的长度、宽度和颜色。 | Trail Renderer |

---

## 场景 (Scene)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **LoadScene** | 让您使用各种方法加载目标场景，可以是原生方法或使用 MMTools 的加载屏幕。 | - |
| **UnloadScene** | 让您卸载场景，可以通过其构建索引或名称指定。 | - |

---

## 弹簧系统 (Springs)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Float Spring** | 控制任何浮点弹簧（晕影强度、光照、时间缩放等），可以直接或通过事件控制。 | - |
| **Vector2 Spring** | 控制任何 Vector2 弹簧（纹理偏移等）。 | - |
| **Vector3 Spring** | 控制任何 Vector3 弹簧（位置、缩放等）。 | - |
| **Vector4 Spring** | 控制任何 Vector4 弹簧。 | - |
| **Color Spring** | 控制任何颜色弹簧（光照颜色、精灵颜色、图像等）。 | - |

---

## TextMesh Pro

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **TextMeshPro Font Size** | 让您随时间修改 TMP 字体的大小。 | TextMeshPro |
| **TextMeshPro Text** | 让您修改目标 TMP 文本组件的文本。 | TextMeshPro |
| **TextMeshPro Character Spacing** | 随时间更改 TMP 文本中字符之间的水平间距。 | TextMeshPro |
| **TextMeshPro Count To** | 让您使用从 A 到 B 随时间变化的浮点值或舍入值更新目标 TMP 文本。 | TextMeshPro |
| **TextMeshPro Count To Long** | 与 CountTo 相同，但使用 long 而不是浮点数（适用于计数到非常大的数字）。 | TextMeshPro |
| **TextMeshPro Word Spacing** | 随时间更改 TMP 文本中单词之间的水平间距。 | TextMeshPro |
| **TextMeshPro Line Spacing** | 随时间更改 TMP 文本中行之间的垂直间距。 | TextMeshPro |
| **TextMeshPro Paragraph Spacing** | 随时间更改 TMP 文本中段落之间的垂直间距。 | TextMeshPro |
| **TextMeshPro Color** | 随时间更改文本颜色。 | TextMeshPro |
| **TextMeshPro Alpha** | 随时间更改文本 alpha。 | TextMeshPro |
| **TextMeshPro Outline Width** | 随时间更改文本的轮廓宽度。 | TextMeshPro |
| **TextMeshPro Outline Color** | 随时间更改文本的轮廓颜色。 | TextMeshPro |
| **TextMeshPro Dilate** | 将调整文本轮廓在距离场中的位置。 | TextMeshPro |
| **TextMeshPro Softness** | 将让您设置文本轮廓的柔度动画。 | TextMeshPro |
| **TextMeshPro TextReveal** | 让您随时间逐字符、逐词或逐行显示目标文本。 | TextMeshPro |

---

## 时间控制 (Time)

> **注意：** 所有与时间相关的反馈都使用 MMTimeManager API。如果您决定使用其中任何一个，并计划在其他脚本中修改时间缩放，最好通过此 API 进行所有时间缩放更改。时间管理器处理一堆时间缩放，让您可以，例如，在已经减慢的时间缩放上进一步减慢一段时间，然后回到它。如果您绕过它并直接访问时间缩放 API，它将不知道您的更改，这将导致问题。如果您不想使用它，您可能需要考虑创建专门针对您自己的时间缩放 API 的反馈。

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Freeze Frame** | 在您选择的短持续时间内冻结时间缩放。需要场景中有 TimeManager。 | TimeManager |
| **Time Modifier** | 完全控制时间，减慢它，加速它，带有可选的自定义插值。您还可以触发 Change 或 Reset 时间修改，让您无限期地将时间缩放更改为新值，或将其重置为其先前的值。需要场景中有 TimeManager。 | TimeManager |

---

## 变换 (Transform)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Position** | 让您随时间调整变换的位置，具有不同的模式：A 到 B 将以指定的速度、持续时间和加速度将对象从初始位置移动到目标位置。沿曲线将沿定义的曲线移动对象，具有重新映射的值，在任何或所有 3 个轴上。到目标将对象移动到指定的目标。 | Transform |
| **Rotation** | 让您随时间处理变换的旋转，包含选项。类似于位置反馈，您可以在绝对模式、加法模式（在播放开始时添加到其当前旋转）或到定义的目标旋转对象。 | Transform |
| **Scale** | 让您随时间设置变换的缩放动画。包含与位置和旋转反馈类似的选项和设置。 | Transform |
| **Position Spring** | 使用弹簧移动或撞击目标的位置。 | Transform |
| **Rotation Spring** | 使用弹簧移动或撞击目标的旋转。 | Transform |
| **Scale Spring** | 使用弹簧移动或撞击目标的缩放。 | Transform |
| **Squash & Stretch Spring** | 通过使用弹簧挤压和拉伸来移动或撞击目标的缩放。 | Transform |
| **Wiggle** | 让您随时间处理旋转、缩放和位置。您需要在目标对象上有一个 MMWiggle 组件才能工作。 | MMWiggle |
| **Rotate Position Around** | 让您围绕另一个中心对象旋转目标对象，具有完整的轴控制。 | Transform |
| **DestinationTransform** | 让您设置变换的所有属性（位置、旋转、缩放）的动画以匹配目标变换的属性。 | Transform |
| **SquashAndStretch** | 在轴线上修改对象的缩放，而其他两个轴线（或仅一个）自动修改以保持质量。这需要标准化的缩放（见下面的注释）。 | Transform |
| **Position Shake** | 让您激活目标位置震动器。震动器将在指定持续时间内移动其目标对象的位置，在某个范围内并沿某个方向。您可以控制该震动的随机性，以及其随时间衰减。这需要一个或多个 MMPositionShaker。 | MMPositionShaker |
| **Rotation Shake** | 让您激活目标旋转震动器。震动器将在指定持续时间内移动其目标对象的位置，在某个范围内并沿某个方向。您可以控制该震动的随机性，以及其随时间衰减。这需要一个或多个 MMRotationShaker。 | MMRotationShaker |
| **Scale Shake** | 让您激活目标缩放震动器。震动器将在指定持续时间内移动其目标对象的位置，在某个范围内并沿某个方向。您可以控制该震动的随机性，以及其随时间衰减。这需要一个或多个 MMScaleShaker。 | MMScaleShaker |
| **Look At** | 让您旋转一个变换以使其面向另一个目标变换（或方向，或特定的世界坐标），包含可选的轴锁定和事件/震动器支持，在这种情况下，您需要在目标上有一个 MMLookAtShaker。 | MMLookAtShaker |
| **Set Parent** | 让您更改目标变换的父变换。 | Transform |

### 关于缩放的注意事项

在处理缩放（挤压和拉伸、缩放震动、缩放弹簧等）时，您需要确保您定位的变换具有标准化的缩放 1,1,1。这并不意味着您不能在具有其他缩放的变换上使用这些反馈，您只需要将它们放在容器对象下即可。以下是层次结构的示例：

```
MyCharacter (您预制件的主对象，可能有一些逻辑、CharacterController 等，缩放 1,1,1)
└── MyModelContainer (您模型的可选容器，缩放 1,1,1)
    └── MySquashAndStretchContainer (空对象，缩放 1,1,1，您使用 S&S 反馈定位它)
        └── MyActualModel (您的网格渲染器，缩放可以是任何您想要的)
```

请注意，这种解耦在许多其他情况下也很有用（以各种速度在多个轴上旋转对象，实现复杂的平移等）。

---

## 用户界面 (UI)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **ImageRaycastTarget** | 此反馈将让您控制目标图像的 RaycastTarget 参数，在播放时打开或关闭它。 | Image |
| **CanvasGroup** | 让您随时间控制 CanvasGroup 的 alpha。 | CanvasGroup |
| **CanvasGroupBlocksRaycasts** | 让您在播放时打开或关闭目标 CanvasGroup 的 BlocksRaycast 参数。 | CanvasGroup |
| **Graphic** | 让您随时间更改目标 Graphic 的颜色。 | Graphic |
| **Graphic CrossFade** | 让您在目标 Graphic 上触发交叉淡入淡出。 | Graphic |
| **Image** | 让您随时间处理 Image 的颜色。 | Image |
| **Image Alpha** | 让您随时间处理 Image 的 alpha。 | Image |
| **Image Fill** | 让您随时间处理 Image 的填充。 | Image |
| **Image Material** | 让您更改目标 Image 的材质。 | Image |
| **Image Sprite** | 让您更改目标 Image 的精灵。 | Image |
| **Image Texture Offset** | 随时间设置 Image 的纹理偏移动画。 | Image |
| **Image Texture Scale** | 随时间设置 Image 的纹理缩放动画。 | Image |
| **Raycast Target** | 让您控制目标图像的 RaycastTarget 参数，在播放时打开或关闭它。 | Image |
| **RectTransformAnchor** | 让您随时间控制 RectTransform 的最小和最大锚点位置。 | RectTransform |
| **RectTransformPivot** | 让您控制 RectTransform 的枢轴点的位置。 | RectTransform |
| **RectTransformOffset** | 让您控制矩形左下角相对于左下锚点的偏移，以及矩形右上角相对于右上锚点的偏移。 | RectTransform |
| **RectTransformSizeDelta** | 让您随时间设置此 RectTransform 相对于锚点之间距离的大小的动画。 | RectTransform |
| **Floating Text** | 让您轻松生成浮动文本（通常是伤害文本，但不限于此）。 | - |
| **Text** | 让您控制目标 Text 的内容。 | Text |
| **TextColor** | 让您随时间更改目标 Text 的颜色。 | Text |
| **TextFontSize** | 让您更改目标文本的字体大小。 | Text |
| **VideoPlayer** | 此反馈将让您以各种方式控制视频播放器（播放、暂停、切换、停止、准备、前进、后退、设置播放速度、设置直接音频音量、设置直接音频静音、转到帧、切换循环）。 | VideoPlayer |

---

## URP 体积 (URP Volume)

> **注意：** 所有这些都需要在 Volume 上有相应的 URP shaker 才能正常工作。确保在使用 URP 时选择 URP 版本的着色器和反馈，否则将无法工作。

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Bloom URP** | 随时间控制泛光强度。 | URP Volume |
| **Chromatic Aberration URP** | 随时间控制色差效果的强度。 | URP Volume |
| **Color Adjustments URP** | 让您使用许多颜色调整选项：后期曝光、饱和度、色调偏移、对比度等。 | URP Volume |
| **Depth of Field URP** | 让您随时间控制景深参数。 | URP Volume |
| **Global PP Volume Auto Blend URP** | 补间 PostProcessing 体积的权重。 | URP Volume |
| **Lens Distortion URP** | 按需进行镜头畸变。 | URP Volume |
| **Motion Blur URP** | 随时间控制运动模糊级别。 | URP Volume |
| **Panini Projection URP** | 随时间调整 panini 投影的距离和裁剪以适应。 | URP Volume |
| **Vignette URP** | 随时间控制晕影参数。 | URP Volume |
| **White Balance URP** | 随时间控制白平衡参数。 | URP Volume |

---

## 其他 (Various)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **Light** | 随时间完全控制光照的强度和颜色。 | Light |
| **Light 2D** | 随时间完全控制 URP 2D 光照的强度和颜色（以及更多）。 | Light 2D |

---

## 调试 (Debug)

| 反馈名称 | 描述 | 所需组件 |
|---------|------|----------|
| **DebugBreak** | 在反馈播放时导致 Debug.Break()。 | - |
| **DebugComment** | 让您在检查器中存储文本，如果您想留下关于为什么以某种方式设置反馈的注释，这很有用。可以选择将其输出到控制台。 | - |
| **DebugLog** | 让您使用不同的方法（MMDebug、警告、错误、日志等）将调试消息输出到控制台。 | - |

---

## 🎯 使用提示

1. **组件要求**：许多反馈需要特定的组件才能正常工作，请确保在目标对象上添加了所需的组件。

2. **层级结构**：对于涉及缩放的反馈，建议使用容器对象来保持标准化的缩放。

3. **性能优化**：对于频繁使用的反馈，考虑使用缓存模式而不是按需实例化。

4. **调试**：大多数反馈都支持编辑器预览，可以在不运行游戏的情况下测试效果。

5. **组合使用**：可以组合多个反馈来创建复杂的视觉效果。

---

## 🔗 相关资源

- [API 文档](https://feel-docs.moremountains.com/)
- [示例场景](https://github.com/More-Mountains/Feel)
- [社区支持](https://discord.gg/moremountains)

---

<div align="center">

**📚 反馈总数：约 150+ 个不同的反馈效果**

</div>
