import { Router } from 'express';
import accountController from '../controllers/account.controller.js';
import authenticate from '../middlewares/auth.js';

const router = Router();

router.use(authenticate);

router.get('/', accountController.list);
router.get('/:id', accountController.get);
router.post('/', accountController.create);
router.patch('/:id', accountController.update);
router.delete('/:id', accountController.remove);

export default router;
