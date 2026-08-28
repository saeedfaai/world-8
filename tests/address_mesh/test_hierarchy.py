import unittest
from services.address_mesh.hierarchy import *


def chain():
    top = RoleBinding('rb-top','arch-1','AI_ARCHITECT','TOP_GUARDIAN','WORLD')
    g = RoleBinding('rb-g','arch-2','AI_ARCHITECT','GUARDIAN','COMPANY','rb-top')
    mm = RoleBinding('rb-mm','mason-1','AI_MASON','MASTER_MASON','COMPANY','rb-g')
    m = RoleBinding('rb-m','mason-2','AI_MASON','MASON','COMPANY','rb-mm')
    return top,g,mm,m


class Tests(unittest.TestCase):
    def test_valid_chain(self):
        validate_binding_graph(chain())

    def test_ai_mason_cannot_be_guardian(self):
        with self.assertRaisesRegex(RoleHierarchyError, 'ACTOR_KIND_ROLE_NOT_ELIGIBLE'):
            RoleBinding('x','m','AI_MASON','GUARDIAN','COMPANY','p')

    def test_top_must_be_world(self):
        with self.assertRaisesRegex(RoleHierarchyError, 'TOP_GUARDIAN_SCOPE_MUST_BE_WORLD'):
            RoleBinding('x','a','AI_ARCHITECT','TOP_GUARDIAN','COMPANY')

    def test_non_top_requires_parent(self):
        with self.assertRaisesRegex(RoleHierarchyError, 'NON_TOP_ROLE_REQUIRES_PARENT'):
            RoleBinding('x','a','AI_ARCHITECT','GUARDIAN','COMPANY')

    def test_parent_level_exact(self):
        top,g,mm,m = chain()
        bad = RoleBinding('bad','mason-3','AI_MASON','MASON','COMPANY','rb-g')
        with self.assertRaisesRegex(RoleHierarchyError, 'ROLE_PARENT_LEVEL_INVALID'):
            validate_binding_graph((top,g,mm,m,bad))

    def test_scope_mismatch_fails(self):
        top = RoleBinding('t','a1','AI_ARCHITECT','TOP_GUARDIAN','WORLD')
        g = RoleBinding('g','a2','AI_ARCHITECT','GUARDIAN','COMPANY','t')
        mm = RoleBinding('mm','m1','AI_MASON','MASTER_MASON','TRADING','g')
        with self.assertRaisesRegex(RoleHierarchyError, 'ROLE_PARENT_SCOPE_MISMATCH'):
            validate_binding_graph((top,g,mm))

    def test_only_one_top(self):
        a = RoleBinding('a','a1','AI_ARCHITECT','TOP_GUARDIAN','WORLD')
        b = RoleBinding('b','a2','AI_ARCHITECT','TOP_GUARDIAN','WORLD')
        with self.assertRaisesRegex(RoleHierarchyError, 'MULTIPLE_ACTIVE_TOP_GUARDIANS_FOR_WORLD'):
            validate_binding_graph((a,b))

    def test_role_descent_one_level(self):
        s = RoleSession('s','arch','rb-top','TOP_GUARDIAN','WORLD')
        s2 = descend_role(s,'GUARDIAN',target_binding_id='rb-g',target_scope_ref='COMPANY')
        self.assertEqual(s2.current_role, RoleKind.GUARDIAN)
        self.assertEqual(s2.descent_seq, 1)
        self.assertEqual(s2.inherited_privileges, ())

    def test_role_ascent_or_skip_forbidden(self):
        s = RoleSession('s','arch','rb-g','GUARDIAN','COMPANY')
        for target in ('TOP_GUARDIAN','MASON'):
            with self.assertRaisesRegex(RoleHierarchyError, 'ROLE_DESCENT_MUST_BE_ONE_LEVEL_DOWN'):
                descend_role(s,target,target_binding_id='x',target_scope_ref='COMPANY')

    def test_privilege_carry_forbidden(self):
        with self.assertRaisesRegex(RoleHierarchyError, 'PRIVILEGE_INHERITANCE_FORBIDDEN'):
            RoleSession('s','a','b','MASON','COMPANY',inherited_privileges=('TOP_WRITE',))

    def test_message_directions(self):
        top,g,mm,m = chain()
        self.assertEqual(message_direction(g,mm), MessageDirection.DOWNWARD)
        self.assertEqual(message_direction(m,mm), MessageDirection.UPWARD)
        g2 = RoleBinding('g2','a3','AI_ARCHITECT','GUARDIAN','TRADING','rb-top')
        self.assertEqual(message_direction(g,g2), MessageDirection.LATERAL)

    def test_message_has_no_authority(self):
        with self.assertRaisesRegex(RoleHierarchyError, 'MESSAGE_AUTHORITY_EFFECT_FORBIDDEN'):
            HierarchyMessageEnvelope('msg','a','b','DOWNWARD_DIRECTIVE',authority_effect='ALLOW')

    def test_supervisor_and_reports(self):
        top,g,mm,m = chain()
        by = {x.binding_id:x for x in chain()}
        self.assertEqual(immediate_supervisor(m,by).binding_id,'rb-mm')
        self.assertEqual([x.binding_id for x in direct_reports(g,chain())],['rb-mm'])
        report = ReportEnvelope.build(reporter=m,supervisor=mm,source_refs=['journal:1','checkpoint:2'],summary='done')
        self.assertTrue(report.report_id.startswith('report-'))

    def test_report_skip_level_forbidden(self):
        top,g,mm,m = chain()
        with self.assertRaisesRegex(RoleHierarchyError, 'REPORT_MUST_TARGET_IMMEDIATE_SUPERVISOR'):
            ReportEnvelope.build(reporter=m,supervisor=g,source_refs=['x'],summary='x')

    def test_subtree(self):
        top,g,mm,m = chain()
        self.assertEqual(subtree('rb-g',chain()),('rb-g','rb-mm','rb-m'))


if __name__ == '__main__': unittest.main()
