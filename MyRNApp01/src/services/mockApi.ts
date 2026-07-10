export type SkillListItem = {
  id: string;
  title: string;
  description: string;
};

export type MockProfile = {
  candidate: string;
  focus: string;
  highlights: string[];
};

export function wait(ms: number) {
  return new Promise<void>(resolve => setTimeout(resolve, ms));
}

export async function fetchSkillPage(
  page: number,
  pageSize = 20,
): Promise<SkillListItem[]> {
  await wait(350);

  return Array.from({ length: pageSize }, (_, index) => {
    const rank = (page - 1) * pageSize + index + 1;
    return {
      id: `skill-${rank}`,
      title: `RN 面试点 ${rank}`,
      description:
        rank % 2 === 0
          ? '关注列表渲染、对象引用稳定性与跨端一致性'
          : '关注 New Architecture、工程化与 Native 集成能力',
    };
  });
}

export async function fetchMockProfile(
  shouldFail = false,
): Promise<MockProfile> {
  await wait(700);
  if (shouldFail) {
    throw new Error('模拟网络异常：服务端返回 500');
  }

  return {
    candidate: 'RN Interview Demo',
    focus: '新架构 / 性能优化 / 工程化',
    highlights: [
      'TurboModule 使用 Codegen + Native 双端实现',
      'Fabric 组件可动态控制原生 UI 展示',
      '基础能力 demo 支持面试讲解与可视化结果',
    ],
  };
}

export async function submitFormMock(values: {
  name: string;
  email: string;
  password: string;
}) {
  await wait(800);
  if (values.email.includes('fail')) {
    throw new Error('模拟提交失败：邮箱命中了失败规则');
  }

  return {
    ok: true,
    message: `提交成功，欢迎 ${values.name}`,
  };
}
