import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

/**
 * Creating a sidebar enables you to:
 - create an ordered group of docs
 - render a sidebar for each doc of that group
 - provide next/previous navigation

 The sidebars can be generated from the filesystem, or explicitly defined here.

 Create as many sidebars as you want.
 */
const sidebars: SidebarsConfig = {
  questSidebar: [
    'introduction',
    'getting-started',
    {
      type: 'category',
      label: 'Language Reference',
      collapsed: false,
      items: [
        'language/objects',
        'language/types',
        'language/variables',
        'language/control-flow',
        'language/loops',
        'language/functions',
        'language/builtins',
        'language/modules',
        'language/exceptions',
      ],
    },
    {
      type: 'category',
      label: 'Built-in Types',
      collapsed: true,
      items: [
        {
          type: 'doc',
          id: 'types/number',
          label: 'Int, Float, Decimal',
        },
        {
          type: 'doc',
          id: 'types/bigint',
          label: 'BigInt',
        },
        {
          type: 'doc',
          id: 'types/bool',
          label: 'Bool',
        },
        {
          type: 'doc',
          id: 'types/nil',
          label: 'Nil',
        },
        {
          type: 'doc',
          id: 'types/string',
          label: 'String',
        },
        {
          type: 'doc',
          id: 'types/bytes',
          label: 'Bytes',
        },
        {
          type: 'doc',
          id: 'types/array',
          label: 'Array',
        },
        {
          type: 'doc',
          id: 'types/dicts',
          label: 'Dict',
        },
      ],
    },
    {
      type: 'category',
      label: 'Standard Library',
      collapsed: true,
      items: [
        'stdlib/index',
        {
          type: 'category',
          label: 'Core Modules',
          collapsed: true,
          items: [
            'stdlib/math',
            'stdlib/ndarray',
            'stdlib/str',
            'stdlib/sys',
            'stdlib/os',
            'stdlib/time',
            'stdlib/io',
          ],
        },
        {
          type: 'category',
          label: 'Encoding & Compression',
          collapsed: true,
          items: [
            'stdlib/encoding',
            'stdlib/json',
            'stdlib/urlparse',
            'stdlib/compress',
          ],
        },
        {
          type: 'category',
          label: 'Data & Crypto',
          collapsed: true,
          items: [
            'stdlib/hash',
            'stdlib/crypto',
            'stdlib/uuid',
            'stdlib/rand',
          ],
        },
        {
          type: 'category',
          label: 'Database',
          collapsed: true,
          items: [
            'stdlib/database',
          ],
        },
        {
          type: 'category',
          label: 'Web & Network',
          collapsed: true,
          items: [
            'stdlib/http',
            'stdlib/html_templates',
            'stdlib/serial',
          ],
        },
        {
          type: 'category',
          label: 'Development & Testing',
          collapsed: true,
          items: [
            'stdlib/test',
            'stdlib/regex',
            'stdlib/conf',
            'stdlib/term',
          ],
        },
        {
          type: 'category',
          label: 'Process Control',
          collapsed: true,
          items: [
            'stdlib/process',
          ],
        },
      ],
    },
    {
      type: 'category',
      label: 'Advanced Topics',
      collapsed: true,
      items: [
        'advanced/system-variables',
      ],
    },
  ],
};

export default sidebars;
