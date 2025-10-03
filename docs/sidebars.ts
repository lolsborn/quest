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
      collapsed: false,
      items: [
        'types/number',
        'types/string',
        'types/array',
        'types/dicts',
      ],
    },
    {
      type: 'category',
      label: 'Standard Library',
      collapsed: false,
      items: [
        'stdlib/index',
        'stdlib/math',
        'stdlib/str',
        'stdlib/io',
        'stdlib/json',
        'stdlib/hash',
        'stdlib/crypto',
        'stdlib/encoding',
        'stdlib/regex',
        'stdlib/sys',
        'stdlib/os',
        'stdlib/time',
        'stdlib/term',
        'stdlib/test',
      ],
    },
    {
      type: 'category',
      label: 'Advanced Topics',
      collapsed: false,
      items: [
        'advanced/system-variables',
      ],
    },
  ],
};

export default sidebars;
