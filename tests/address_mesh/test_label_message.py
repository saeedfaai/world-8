import unittest
from services.address_mesh.label_message import *
from services.address_mesh.hierarchy import RoleBinding


def chain():
    top=RoleBinding('top','arch','AI_ARCHITECT','TOP_GUARDIAN','WORLD')
    g=RoleBinding('g','guardian','AI_ARCHITECT','GUARDIAN','COMPANY','top')
    mm=RoleBinding('mm','master','AI_MASON','MASTER_MASON','COMPANY','g')
    m1=RoleBinding('m1','mason1','AI_MASON','MASON','COMPANY','mm')
    m2=RoleBinding('m2','mason2','AI_MASON','MASON','COMPANY','mm')
    return top,g,mm,m1,m2

class Tests(unittest.TestCase):
    def test_labels_are_append_projection(self):
        ev=[LabelEvent('1','fn','RUNTIME:SUPABASE','ATTACH','mm','work:1',1),LabelEvent('2','fn','RISK:MONEY','ATTACH','mm','work:1',2),LabelEvent('3','fn','RISK:MONEY','DETACH','mm','work:2',3)]
        self.assertEqual(project_labels(ev),('RUNTIME:SUPABASE',))
    def test_label_never_grants_authority(self):
        with self.assertRaisesRegex(LabelMessageError,'LABEL_AUTHORITY_EFFECT_FORBIDDEN'):
            LabelEvent('1','fn','X','ATTACH','mm','x',1,authority_effect='ALLOW')
    def test_message_envelope_never_grants_authority(self):
        with self.assertRaisesRegex(LabelMessageError,'MESSAGE_AUTHORITY_EFFECT_FORBIDDEN'):
            MessageEnvelope('m','a',None,'STATUS',address_targets=(AddressMessageTarget('TAG','X'),),authority_effect='ALLOW')
    def test_message_needs_role_or_address_target(self):
        with self.assertRaisesRegex(LabelMessageError,'MESSAGE_TARGET_REQUIRED'):
            MessageEnvelope('m','a',None,'STATUS')
    def test_message_can_target_role_and_code_context_separately(self):
        msg=MessageEnvelope('m','master','mm','POLICY_NOTICE',role_targets=(RoleMessageTarget('ROLE_KIND','MASON','COMPANY'),),address_targets=(AddressMessageTarget('TAG','CHANNEL:TELEGRAM'),))
        self.assertEqual(resolve_role_recipients(msg,chain()),('mason1','mason2'))
        self.assertEqual(msg.address_targets[0].target_ref,'CHANNEL:TELEGRAM')
    def test_supervisor_target_is_immediate(self):
        msg=MessageEnvelope('m','mason1','m1','UPWARD_REPORT',role_targets=(RoleMessageTarget('SUPERVISOR','SELF'),))
        self.assertEqual(resolve_role_recipients(msg,chain()),('master',))
    def test_subtree_targets_all_descendants_and_root(self):
        msg=MessageEnvelope('m','guardian','g','STATUS',role_targets=(RoleMessageTarget('SUBTREE','g'),))
        self.assertEqual(resolve_role_recipients(msg,chain()),('guardian','mason1','mason2','master'))
    def test_role_kind_scope_filters(self):
        extra=RoleBinding('tm','tm','AI_MASON','MASON','TRADING','tmm')
        # don't need graph validation for isolated recipient-directory test
        msg=MessageEnvelope('m','arch','top','STATUS',role_targets=(RoleMessageTarget('ROLE_KIND','MASON','COMPANY'),))
        self.assertEqual(resolve_role_recipients(msg,(*chain(),extra)),('mason1','mason2'))
    def test_deterministic_message_id(self):
        self.assertEqual(deterministic_message_id('a','k','h'),deterministic_message_id('a','k','h'))

if __name__=='__main__': unittest.main()
