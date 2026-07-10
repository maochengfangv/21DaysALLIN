import React, { useState } from 'react';
import { Text, TextInput } from 'react-native';
import { Header } from '../../components/common/Header';
import {
  ActionButton,
  ResultCard,
  ScreenContainer,
  uiStyles,
} from '../../components/ui';
import { submitFormMock } from '../../services/mockApi';
import { getErrorMessage } from '../../utils/error';
import type { ScreenProps } from '../types';

export function FormScreen({ goBack }: ScreenProps) {
  const [form, setForm] = useState({ name: '', email: '', password: '' });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitting, setSubmitting] = useState(false);
  const [result, setResult] = useState('');

  const validate = () => {
    const nextErrors: Record<string, string> = {};
    if (form.name.trim().length < 2) {
      nextErrors.name = '姓名至少 2 个字符';
    }
    if (!/^\S+@\S+\.\S+$/.test(form.email)) {
      nextErrors.email = '邮箱格式不正确';
    }
    if (form.password.length < 6) {
      nextErrors.password = '密码至少 6 位';
    }
    setErrors(nextErrors);
    return Object.keys(nextErrors).length === 0;
  };

  const submit = async () => {
    if (!validate()) {
      return;
    }
    try {
      setSubmitting(true);
      const response = await submitFormMock(form);
      setResult(response.message);
    } catch (error) {
      setResult(getErrorMessage(error));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <Header title="Form Validation" goBack={goBack} />
      <ScreenContainer
        title="Form Validation Demo"
        summary="用最小实现展示输入校验、错误提示与提交状态管理。"
        points={[
          '提交前统一校验，避免无效请求',
          '错误提示贴近字段，便于用户修正',
          'submitting 状态防止重复提交',
        ]}
      >
        <ResultCard title="表单">
          <Text style={uiStyles.label}>姓名</Text>
          <TextInput
            style={uiStyles.input}
            value={form.name}
            onChangeText={name => setForm(prev => ({ ...prev, name }))}
          />
          {errors.name ? (
            <Text style={uiStyles.error}>{errors.name}</Text>
          ) : null}

          <Text style={uiStyles.label}>邮箱</Text>
          <TextInput
            style={uiStyles.input}
            value={form.email}
            onChangeText={email => setForm(prev => ({ ...prev, email }))}
            autoCapitalize="none"
          />
          {errors.email ? (
            <Text style={uiStyles.error}>{errors.email}</Text>
          ) : null}

          <Text style={uiStyles.label}>密码</Text>
          <TextInput
            style={uiStyles.input}
            value={form.password}
            onChangeText={password => setForm(prev => ({ ...prev, password }))}
            secureTextEntry
          />
          {errors.password ? (
            <Text style={uiStyles.error}>{errors.password}</Text>
          ) : null}

          <ActionButton
            title={submitting ? '提交中...' : '提交'}
            onPress={submit}
          />
        </ResultCard>

        <ResultCard title="可见结果">{result || '等待提交'}</ResultCard>
      </ScreenContainer>
    </>
  );
}
