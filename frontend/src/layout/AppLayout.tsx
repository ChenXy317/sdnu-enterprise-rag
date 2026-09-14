import { useState } from 'react'
import { Layout, Menu, Typography, Button, Tag } from 'antd'
import { FileTextOutlined, MessageOutlined, LogoutOutlined, SettingOutlined } from '@ant-design/icons'
import { Link, Outlet, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'
import { useIsMobile } from '../hooks/useIsMobile'

const { Header, Sider, Content } = Layout

const TITLES: Record<string, { kicker: string; title: string }> = {
  chat: { kicker: 'Knowledge', title: '知识库对话' },
  docs: { kicker: 'Corpus', title: '文档管理' },
  settings: { kicker: 'System', title: '设置' },
}

const NAV = [
  { key: 'chat', icon: <MessageOutlined />, label: '对话', fullLabel: '知识库对话', to: '/chat' },
  { key: 'docs', icon: <FileTextOutlined />, label: '文档', fullLabel: '文档管理', to: '/docs' },
  { key: 'settings', icon: <SettingOutlined />, label: '设置', fullLabel: '设置', to: '/settings' },
] as const

export default function AppLayout() {
  const loc = useLocation()
  const nav = useNavigate()
  const { auth, logout } = useAuth()
  const isMobile = useIsMobile()
  const [collapsed, setCollapsed] = useState(false)
  const key = loc.pathname.startsWith('/docs')
    ? 'docs'
    : loc.pathname.startsWith('/settings')
      ? 'settings'
      : 'chat'
  const heading = TITLES[key]
  const initial = (auth?.email || auth?.user_id || 'U').slice(0, 1).toUpperCase()

  return (
    <Layout className={'app-shell' + (isMobile ? ' is-mobile' : '')}>
      {!isMobile && (
        <Sider
          className="app-sider"
          breakpoint="lg"
          collapsedWidth={72}
          collapsible
          collapsed={collapsed}
          onCollapse={setCollapsed}
          theme="light"
          width={232}
        >
          <div className={'brand-lockup' + (collapsed ? ' is-collapsed' : '')}>
            <img src="/sdnu-emblem-64.png" alt="山东师范大学校徽" width={40} height={40} />
            {!collapsed && (
              <div style={{ minWidth: 0 }}>
                <div className="brand-name">山东师范大学</div>
                <div className="brand-sub">知识库问答</div>
              </div>
            )}
          </div>
          {!collapsed && <p className="brand-motto">弘德明志 · 博学笃行</p>}
          <Menu
            className="app-menu"
            mode="inline"
            selectedKeys={[key]}
            items={NAV.map((item) => ({
              key: item.key,
              icon: item.icon,
              label: <Link to={item.to}>{item.fullLabel}</Link>,
            }))}
          />
        </Sider>
      )}
      <Layout>
        <Header className="app-header">
          {isMobile ? (
            <div className="header-brand-mini">
              <img src="/sdnu-emblem-64.png" alt="" width={28} height={28} />
              <div className="header-title">{heading.title}</div>
            </div>
          ) : (
            <div>
              <div className="header-kicker">{heading.kicker}</div>
              <div className="header-title">{heading.title}</div>
            </div>
          )}
          <div className="header-user">
            {auth?.tenant_id && (
              <Tag className="tenant-tag" color="red">{auth.tenant_id}</Tag>
            )}
            {!isMobile && (
              <div className="user-chip">
                <span className="user-avatar">{initial}</span>
                <span className="user-email">
                  <Typography.Text style={{ maxWidth: 180 }} ellipsis>
                    {auth?.email || auth?.user_id}
                  </Typography.Text>
                </span>
              </div>
            )}
            <Button
              className="logout-btn"
              icon={<LogoutOutlined />}
              onClick={() => { logout(); nav('/login') }}
            >
              <span className="logout-label">退出</span>
            </Button>
          </div>
        </Header>
        <Content className={'app-content' + (isMobile ? ' is-mobile' : '')}>
          <Outlet />
        </Content>
      </Layout>
      {isMobile && (
        <nav className="app-tabbar" aria-label="主导航">
          {NAV.map((item) => (
            <button
              key={item.key}
              type="button"
              className={item.key === key ? 'is-active' : undefined}
              onClick={() => nav(item.to)}
            >
              {item.icon}
              <span>{item.label}</span>
            </button>
          ))}
        </nav>
      )}
    </Layout>
  )
}
